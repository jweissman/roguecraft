/**
 *  roguecraft client
 */
//var Roguecraft = {
//  map: null,
//  groundLayer: null
//};
var game = new Phaser.Game(800, 600, Phaser.AUTO, 'roguecraft', { preload: preload, create: create, update: update, render: render });
var map;
var groundLayer;
var fogLayer;

var warrior;
var explored = new Array();
var unexplored = new Array();
var other_warriors = new Array();
var treasure = new Array();

var ws;
var cursors;
var hero_id;
var depth = 0;
var levelText;

function preload() {
  //console.log('#preload');

  game.stage.disableVisibilityChange = true;
  game.stage.backgroundColor = "#000000";

  console.log("--- preloading tilemap...!");

  // todo figure out how to load more as needed...
  for (var d=0; d<15; d++) { 
    game.load.tilemap('level'+d, d+'/tilemap.json', null, Phaser.Tilemap.TILED_JSON);
    //game.load.tilemap('entities'+d, d+'/entities.json', null, Phaser.Tilemap.TILED_JSON);
    // load treasure etc? :)
    game.load.text('entities'+d, d+'/entities.json')
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
  //console.log("=== create map for "+depth);
	  //console.log("already have this hero...");
	  //_.select(other_warriors, function(hero) { hero.id == message.hero})
  //game.load.tilemap('level'+depth, depth+'/tilemap.json', null, Phaser.Tilemap.TILED_JSON);
  //console.log("--- should have loaded map for " + depth);
  map = game.add.tilemap('level'+depth);

  map.addTilesetImage('stone');
  map.addTilesetImage('wood');
  map.addTilesetImage('door');
  map.addTilesetImage('up');
  map.addTilesetImage('down');

  groundLayer = map.createLayer('ground');
  //groundLayer.debug = true;
  console.log("created map!");
  //map.setCollisionByExclusion([1,3,4,5]); //#7, 32, 35, 36, 47]);

  console.log("resize world");
  groundLayer.resizeWorld();

  fogLayer = map.createLayer('fog');
  
  // but what's 2/1?
  //map.fill(2,0,0,map.width,map.height,fogLayer);
  console.log("created fog!");
  //fogLayer.alpha = 1; //100.0;
  //fogLayer.resizeWorld();

  //console.log(explored);
  //map.putTile(); //fogLayer.

  //  This creates a simple sprite that is using our loaded image and
  //  displays it on-screen
  console.log("create warrior");
  warrior = game.add.sprite(400, 300, 'warrior');
  warrior.anchor.set(0.5);
  //groundLayer.dirty = true;

  //hero_list.each({
   // create sprite for hero
  //});

  console.log("enabling physics/camera");

  game.physics.enable(warrior);
  game.camera.follow(warrior);

  var text = "level: "+depth;
  var style = { font: "65px Arial", fill: "#ff0044", align: "center" };

  levelText = game.add.text(300, 400, text, style);
  levelText.fixedToCamera = true;

  graphics = game.add.graphics(0,0);
  //entities = JSON.parse(game.cache.getText("entities"+depth));

  // obscure everything to start

  //_.each(explored, function(tile) {
  //  console.log(tile);
  //  graphics.lineStyle(2, 0x000000, 1);
  //});


}

function create() {
  console.log('#create');

  createMap();

  console.log("create cursors");
  cursors = game.input.keyboard.createCursorKeys();


  // setup websockets
  console.log("setup websockets");

  ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
  ws.onopen    = function()  { console.log('websocket opened'); };
  ws.onclose   = function()  { console.log('websocket closed'); }
  ws.onmessage = function(m) { 
    console.log(m);

    message = JSON.parse(m.data);
    //console.log('websocket message: '); 
    //console.log(message);
    //console.log("my hero number: " + hero_id);
    //console.log("hero number sent: " + message.hero);
    if (message.type == 'move') { 
      if (message.id == hero_id) {
	//console.log("moving hero!");
	if (message.depth != depth) {
	  //game.load.tilemap('world', depth+'/tilemap.json', null, Phaser.Tilemap.TILED_JSON);
	  //groundLayer.resizeWorld();
	  depth = message.depth;
	  console.log("load a new tilemap for level "+depth+"?");
	  createMap();
	}

	warrior.body.x = message.x * 32;
	warrior.body.y = message.y * 32;

	console.log("should note explored..?");
	explored = explored || new Array();
	_.each(message.visible, (function(el){explored.push(el);}));
	explored = _.uniq(explored);

	console.log("obscuring");
	graphics.clear();
	map.forEach(function(tile) { 
	  if (_.contains(explored, [tile.x, tile.y])) {
	    graphics.beginFill(0xFFFF0B, 0.2);
	  } else { 
	    graphics.beginFill(0x000000, 0.8);
	  }
	  graphics.drawRect(tile.x*32, tile.y*32, 32, 32);
	  graphics.endFill();
	});

    } else {
      console.log("updating other hero "+message.hero+"...");
      other_hero = _.detect(other_warriors, function(hero) { return hero.id == message.id });
      if (other_hero) {
	//console.log("already have this hero...");
	//_.select(other_warriors, function(hero) { hero.id == message.hero})
	other_hero.sprite.body.x = message.x * 32;
	other_hero.sprite.body.y = message.y * 32;

      } else {
	if (message.depth == depth) {
	  console.log("don't have this hero yet...");
	  new_hero = game.add.sprite(message.x * 32, message.y * 32, 'warrior');
	  game.physics.enable(new_hero);
	  //console.log("added sprite "+message.hero+" at "+message.x+", "+message.y);
	  other_warriors.push({sprite: new_hero, id: message.id}); //, x: message.x * 32, y: message.y * 32});
      }
    }
  }
  // update other warriors...
  //console.log(other_warriors);
  //other_warriors[message.hero] = { x: message.x, y: message.y };
} else if (message.type == 'init') { // should probably move this up top...
  console.log(">>>>> INIT");
  hero_id = message.id;
  warrior.body.x = message.x*32;
  warrior.body.y = message.y*32;
  //createMap();	
  explored = explored || new Array();
  _.each(message.visible, (function(el){explored.push(el);})); //message.visible);
  explored = _.uniq(explored);
}

}
}

function update() {
  //console.log('#update');
  game.physics.arcade.collide(warrior, groundLayer);

  //warrior.body.velocity.x = 0;
  //warrior.body.velocity.y = 0;

  if (cursors.up.isDown)
  {
    //console.log("up");
    //# warrior.body.velocity.y = -200;
    //particleBurst();
    ws.send(JSON.stringify({type: 'move', id: hero_id, direction: 'north'})); //"moved up");

  }
  else if (cursors.down.isDown)
  {
    //console.log("down");
    //warrior.body.velocity.y = 200;
    // particleBurst();
    ws.send(JSON.stringify({type: 'move', id: hero_id, direction: 'south'})); //"moved down");
  }

  if (cursors.left.isDown)
  {
    //warrior.body.velocity.x = -200;
    warrior.scale.x = -1;

    ws.send(JSON.stringify({type: 'move', id: hero_id, direction: 'west'})); //"moved left");
    // particleBurst();
  }
  else if (cursors.right.isDown)
  {
    // warrior.body.velocity.x = 200;
    warrior.scale.x = 1;

    ws.send(JSON.stringify({type: 'move', id: hero_id, direction: 'east'})); //"moved right");
    //# particleBurst();
  }
}

function render() {

  //game.debug.body(warrior);

}
