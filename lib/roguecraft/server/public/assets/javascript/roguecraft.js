/**
 *  a barebones js roguecraft client
 */

console.log("++++++++++ ROGUECRAFT ++++++++++++");

var game = new Phaser.Game(800, 600, Phaser.AUTO, 'roguecraft', { preload: preload, create: create, update: update, render: render });
var map;
var groundLayer;
var entityLayer;

var entities;

var warrior;
var visible = []; //new Array();
var other_warriors = []; // new Array();
var destroyedEntities = [];
//var treasure = new Array();

var graphics;

var ws;
var cursors;

var hero_id;
var depth = 0;
var levelText;

// need to unify around pngs first i think
//var images = [ 'warrior', 'stone', 'wood', 'door', 'up', 'down', 'gold', 'potion', 'scroll' ];

function preload() {
  //console.log("preload");
  game.stage.disableVisibilityChange = true;
  game.stage.backgroundColor = "#000000";

  // todo figure out how to load more as needed... -- may just need to do game 'phases'...
  for (var d=0; d<15; d++) { 
    game.load.tilemap('level'+d, d+'/tilemap.json', null, Phaser.Tilemap.TILED_JSON);
   // game.load.tilemap('entities'+d, d+'/entities.json', null, Phaser.Tilemap.TILED_JSON);
    // load treasure etc? :)
    //game.load.text('entities'+d, d+'/entities.json')
  }

  game.load.image('warrior', 'assets/images/warrior.gif');

  game.load.image('stone', 'assets/images/stone.png');
  game.load.image('wood',  'assets/images/wood.png');

  game.load.image('door',  'assets/images/door.png');

  game.load.image('up',    'assets/images/up.png');
  game.load.image('down',  'assets/images/down.png');

  game.load.image('gold',   'assets/images/gold.png');
  game.load.image('potion', 'assets/images/potion.png');
  game.load.image('scroll', 'assets/images/scroll.png');
}

function createMap() {
  if (groundLayer) { groundLayer.destroy(); }

  map = game.add.tilemap('level'+depth);
  map.addTilesetImage('stone');
  map.addTilesetImage('wood');
  map.addTilesetImage('door');
  map.addTilesetImage('up');
  map.addTilesetImage('down');

  map.addTilesetImage('gold');
  map.addTilesetImage('potion');
  map.addTilesetImage('scroll');

  groundLayer = map.createLayer('ground');
  groundLayer.resizeWorld();

  // ugh -- the fix for this is on the server -- only send a current/updated list of entities to the client
  // i.e., don't cache
  // but that also means we need to refactor for phases/re-downloading the content...
  // maybe time to investigate that, it would at least provide some simple means of starting to break things apart
  // would encourage me to write a backing library of some kind
  if (entities) { 
    entities.forEach(function(e) { 
      //if (_.detect(destroyedEntities, function(de) { 
      //  return de == e.entity_id
      //})) { 
        e.kill(); 
      //}
    })
  } //destroy(); } //true, true); }
  entities = game.add.group(); 
  entities.enableBody = true;
  //
  // note: they come in alphabetical order to ensure we have the same ids (this is the worst thing ever, we should just pass a guid property, that's built-in to phaser!)
  map.createFromObjects('entities', 6, 'gold',   0, true, false, entities); //, entities);
  map.createFromObjects('entities', 7, 'potion', 0, true, false, entities); //, entities);
  map.createFromObjects('entities', 8, 'scroll', 0, true, false, entities); //, entities);
  if (entities) { 
    entities.forEach(function(e) { 
      if (_.detect(destroyedEntities, function(de) { 
        return de == e.entity_id
      })) { 
        e.kill(); 
      }
    })
  } //destroy(); } //true, true); }
  //console.log("CREATED ENTITIES: ");
  //console.log(entities);

  var text = "level: "+depth;
  var style = { font: "65px Arial", fill: "#ff0044", align: "center" };

  if (levelText) { levelText.destroy(); }
  levelText = game.add.text(300, 400, text, style);
  levelText.fixedToCamera = true;

  //graphics = game.add.graphics(0,0);
  //graphics.clear();
}

function setupRealm() {
  createMap();
  createWarrior();
}

function obscure() {
  //console.log("OBSCURE");
  map.forEach(function(tile) { 
    tile.alpha = 0; 
      var entity=null;
      entities.forEach(function(e) { if (e.x == tile.x * 32 && e.y == tile.y * 32) { entity = e; console.log("FOUND IT"); console.log(e); return; } });
      if (entity) { entity.alpha = 0; console.log("MASKING ENTITY"); } // = true; } 
    //var entity =null;
    //entities.forEach(function(e) { e.x == tile.x && e.y == tile.y });
    //if (e) { e.alpha = 0; }
  });
  //entities.forEach(function(entity) { entity.alpha = 0; });
}

// moveHero(x,y) takes map (**tile**) coordinates
function setHeroPosition(x,y) {
  warrior.body.x = x*32;
  warrior.body.y = y*32;
}

function handleMessage(m) {
  message = JSON.parse(m.data);
  command = message.type;
  forMe = message.id == hero_id;
  differentDepth = message.depth != depth;

  if (command == 'move') { 
    if (forMe) {
      if (differentDepth) {
	depth = message.depth;
	setupRealm();
	obscure();
      }
      recalcObscured(message.visible, message.invisible);
      setHeroPosition(message.x, message.y);
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
    setHeroPosition(message.x, message.y);
  } else if (command == 'bye') {
    other_hero = _.detect(other_warriors, function(hero) { return hero.id == message.id });
    if (other_hero) {
      other_hero.sprite.destroy();
      other_warriors = _.without(other_warriors, other_hero);
      console.log("--- other players connected: "+other_warriors.length);
    }
  } else if (command == 'removal') {
    console.log("REMOVE");
    //console.log("need to identify which of the entities need to get removed...");
    //console.log(message);
    //console.log(entities);
    //console.log(entities.getAt(message.id));
    //entity = entities.getAt(message.id);
    var entity = null;
      console.log("- Removing entity with id "+ message.entity_id + ")");
    entities.forEach(function(e) { if (e.entity_id == message.entity_id) { entity = e; return; } });
    if (entity) { // != -1) { 
      console.log("- Removing entity " + entity.name + "("+ message.entity_id + ")");
      entity.kill();
      entity.alpha = 0;
      destroyedEntities.push(message.entity_id);
    }
    //entities.forEach(function(entity) {
    //  console.log(entity);
    //  //console.log(entity.y);
    //  //console.log(entity.id);
    //  if (entity.x == message.x * 32 && entity.y == message.y * 32) {
    //  //  console.log("FOUND ENTITY");
    //    entity.kill();
    //  //  return;
    //  }
    //});
    //entities.getAt(message.id).kill();
  }
}

function createSockets() {
  console.log("setup sockets");
  ws           = new WebSocket('ws://' + window.location.host + window.location.pathname);
  ws.onopen    = function()  { console.log('websocket opened'); };
  ws.onclose   = function()  { console.log('websocket closed'); }
  ws.onmessage = handleMessage;
}

function recalcObscured(newVisible, newInvisible) {
  var changed = false;

  _.each(newVisible, function(position) {
    var x = position[0], y = position[1];
    var tile = map.getTile(x,y,groundLayer);
    if (tile.alpha != 1) { 
      tile.alpha = 1;
      var entity=null;
      entities.forEach(function(e) { if (e.x == tile.x * 32 && e.y == tile.y * 32) { entity = e; } });
      if (entity) { entity.alpha = 1; console.log("UNMASKING!"); } // = true; } 
      //var e = _.detect(entities, function(e) { e.x == tile.x && e.y == tile.y });
      //if (e) { e.alpha = 1; }
      changed = true;
    }
  });

  _.each(newInvisible, function(position) {
    var x = position[0], y = position[1];
    var tile = map.getTile(x,y,groundLayer);
    if (tile.alpha != 0.5) { 
      tile.alpha = 0.5
      var entity=null;
      entities.forEach(function(e) { if (e.x == tile.x * 32 && e.y == tile.y * 32) { entity = e; } });
      if (entity) { entity.alpha = 0.5; } // = true; } 
      //var e = _.detect(entities, function(e) { e.x == tile.x && e.y == tile.y });
      //if (e) { e.alpha = 0.5; }
      changed = true;
    }
  });
  
  if (changed) { groundLayer.dirty = true; }
}

function createWarrior() {
  console.log("create warrior");
  if (warrior) { warrior.kill(); }
  warrior = game.add.sprite(400, 300, 'warrior');
  warrior.anchor.set(0.5);
  game.physics.enable(warrior);
  game.camera.follow(warrior);
}

function create() {
  console.log('#create');
  cursors = game.input.keyboard.createCursorKeys();
  console.log("setup websockets");
  createSockets();
  autoexplore = game.input.keyboard.addKey(Phaser.Keyboard.A);
  autoexplore.onDown.add(automateExploration, this);
}

function move(direction) {
  ws.send(JSON.stringify({type: 'move', id: hero_id, direction: direction}));
}

function moveWest() {
  warrior.scale.x = -1; 
  move('west');
}

function moveEast() {
  warrior.scale.x = 1;
  move('east');
}

function moveNorth() { move('north'); }
function moveSouth() { move('south'); }

function handleCursors() {
  var move = false, direction = '';

  if 	  (cursors.up.isDown    || game.input.keyboard.isDown(Phaser.Keyboard.K))    { moveNorth(); }
  else if (cursors.down.isDown  || game.input.keyboard.isDown(Phaser.Keyboard.J))  { moveSouth(); }
  else if (cursors.left.isDown  || game.input.keyboard.isDown(Phaser.Keyboard.H)) { moveWest(); }
  else if (cursors.right.isDown || game.input.keyboard.isDown(Phaser.Keyboard.L)) { moveEast(); } 
}

function automateExploration() {
  ws.send(JSON.stringify({type: 'autopilot', id: hero_id}));
}

function update() {
  handleCursors();
}

function render() {
  //if (warrior) { game.debug.body(warrior); }
}
