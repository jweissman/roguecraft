/**
 *  a barebones js roguecraft client
 */

console.log("++++++++++ ROGUECRAFT ++++++++++++");

var game = new Phaser.Game(800, 600, Phaser.AUTO, 'roguecraft', { preload: preload, create: create, update: update, render: render });
var map;
var groundLayer;
var fogLayer;

var warrior;
var visible = new Array();
var other_warriors = new Array();
var treasure = new Array();

var graphics;

var ws;
var cursors;

var hero_id;
var depth = 0;
var levelText;

function preload() {
  //console.log("preload");
  game.stage.disableVisibilityChange = true;
  game.stage.backgroundColor = "#000000";

  // todo figure out how to load more as needed... -- may just need to do game 'phases'...
  for (var d=0; d<15; d++) { 
    game.load.tilemap('level'+d, d+'/tilemap.json', null, Phaser.Tilemap.TILED_JSON);
    //game.load.tilemap('entities'+d, d+'/entities.json', null, Phaser.Tilemap.TILED_JSON);
    // load treasure etc? :)
    //game.load.text('entities'+d, d+'/entities.json')
  }

  game.load.image('warrior', 'assets/images/warrior.gif');

  game.load.image('stone', 'assets/images/stone.png');
  game.load.image('wood',  'assets/images/wood.png');
  game.load.image('door',  'assets/images/door.png');
  game.load.image('up',    'assets/images/up.png');
  game.load.image('down',  'assets/images/down.png');

  game.load.image('gold',  'assets/images/gold.png');
}

function createMap() {
  //console.log("create map");

  if (groundLayer) { groundLayer.destroy(); }

  map = game.add.tilemap('level'+depth);

  map.addTilesetImage('stone');
  map.addTilesetImage('wood');
  map.addTilesetImage('door');
  map.addTilesetImage('up');
  map.addTilesetImage('down');

  //obscure();

  groundLayer = map.createLayer('ground');
  groundLayer.resizeWorld();

  var text = "level: "+depth;
  var style = { font: "65px Arial", fill: "#ff0044", align: "center" };

  if (levelText) { levelText.destroy(); }
  levelText = game.add.text(300, 400, text, style);
  levelText.fixedToCamera = true;

  //graphics = game.add.graphics(0,0);
  //graphics.clear();
}

function setupRealm() {
  //console.log("setup realm");
  createMap();
  createWarrior();
}

function obscure() {
  //console.log("OBSCURE");
  map.forEach(function(tile) { tile.alpha = 0; });
}

// moveHero(x,y) takes map (**tile**) coordinates
function moveHero(x,y) {
  //console.log("move hero to "+x+","+y+"!");
  warrior.body.x = x*32;
  warrior.body.y = y*32;
}

function handleMessage(m) {
  //console.log("handle message");
  message = JSON.parse(m.data);
  command = message.type;
  forMe = message.id == hero_id;
  differentDepth = message.depth != depth;

  //console.log("COMMAND RECEIVED: "+command+" (for me? "+forMe+", different depth? "+differentDepth+")");
  //console.log("--- visible: ");
  //console.log(message.visible);

  if (command == 'move') { 
    if (forMe) {
      if (differentDepth) {
	//console.log("CHANGE OF DEPTH DETECTED");
	depth = message.depth;
	setupRealm();
	obscure();
      }
      recalcObscured(message.visible, message.invisible);
      moveHero(message.x, message.y);
    } else {
      other_hero = _.detect(other_warriors, function(hero) { return hero.id == message.id });
      if (other_hero) {
	other_hero.sprite.body.x = message.x * 32;
	other_hero.sprite.body.y = message.y * 32;
	//other_hero.depth = message.depth;

	if (differentDepth) { //message.depth == depth) {
	  other_hero.sprite.alpha = 0;
	} else {
	  other_hero.sprite.alpha = 1;
	}
	
      } else {
	new_hero = game.add.sprite(message.x * 32, message.y * 32, 'warrior');
	game.physics.enable(new_hero);
	other_warriors.push({sprite: new_hero, id: message.id});
      }
    }
  } else if (command == 'init') {
    hero_id = message.id;
    setupRealm();
    obscure();
    recalcObscured(message.visible, message.invisible);
    moveHero(message.x, message.y);
  } else if (command == 'bye') {
    console.log("LATER");
    other_hero = _.detect(other_warriors, function(hero) { return hero.id == message.id });
    if (other_hero) {
      console.log("DESTROY");
      other_hero.sprite.destroy();
      other_warriors = _.without(other_warriors, other_hero);
      console.log("--- other players connected: "+other_warriors.length);
    }
  }
}

function createSockets() {
  console.log("setup sockets");
  ws           = new WebSocket('ws://' + window.location.host + window.location.pathname);
  ws.onopen    = function()  { console.log('websocket opened'); };
  ws.onclose   = function()  { console.log('websocket closed'); }
  ws.onmessage = handleMessage // function(m) { 
}

function recalcObscured(newVisible, newInvisible) {
  //console.log("recalc obscured");
  _.each(newVisible, function(position) {
    var x = position[0], y = position[1];
    var tile = map.getTile(x,y,groundLayer);
    if (tile.alpha != 1) { 
      //console.log("making visible!");
      tile.alpha = 1; //.0;
    }
  });
  _.each(newInvisible, function(position) {
    var x = position[0], y = position[1];
    var tile = map.getTile(x,y,groundLayer);
    if (tile.alpha != 0.5) { 
      //console.log("making visible!");
      tile.alpha = 0.5; //.0;
    }
  });
      groundLayer.dirty = true;

}

function createWarrior() {
  console.log("create warrior");
  //if (warrior) { warrior.destroy(); }
  if (warrior) { warrior.kill(); } //warrior.alpha = 0; }// = null; // ? :)
  //other_warriors = new Array();
  warrior = game.add.sprite(400, 300, 'warrior');
  warrior.anchor.set(0.5);
  //}

  game.physics.enable(warrior);
  game.camera.follow(warrior);
}

function create() {
  console.log('#create');
  cursors = game.input.keyboard.createCursorKeys();

  // setup websockets
  console.log("setup websockets");
  createSockets();

  autoexplore = game.input.keyboard.addKey(Phaser.Keyboard.A);
  autoexplore.onDown.add(automateExploration, this);

  //left = game.input.keyboard.addKey(Phaser.Keyboard.H);
  //left.onDown.add(moveLeft, this);

  ///key3 = game.input.keyboard.addKey(Phaser.Keyboard.THREE);
  ///key3.onDown.add(addPineapple, this);

}

function handleCursors() {
  var move = false, direction = '';

  if 	  (cursors.up.isDown)   { move = true; direction = 'north'; }
  else if (cursors.down.isDown) { move = true; direction = 'south'; }
  else if (cursors.left.isDown)
  {
    warrior.scale.x = -1;
    move = true; direction = 'west';
  }
  else if (cursors.right.isDown)
  {
    warrior.scale.x = 1;
    move = true; direction = 'east';
  }

  if (move) {
    //console.log("move "+direction);
    ws.send(JSON.stringify({type: 'move', id: hero_id, direction: direction}));
  }
}

function automateExploration() {
console.log("AUTOPILOT");
  ws.send(JSON.stringify({type: 'autopilot', id: hero_id}));
}

function update() {
  //game.physics.arcade.collide(warrior, groundLayer);
  handleCursors();
}

function render() {
  //if (warrior) { game.debug.body(warrior); }
}
