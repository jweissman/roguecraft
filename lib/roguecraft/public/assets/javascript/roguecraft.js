var game = new Phaser.Game(800, 600, Phaser.AUTO, 'roguecraft', { preload: preload, create: create, update: update, render: render });
var map;
var groundLayer;
var warrior;
var other_warriors = new Array();
var ws;

function preload() {
  game.stage.disableVisibilityChange = true;
  game.stage.backgroundColor = "#000000";

  game.load.tilemap('world', 'map.json', null, Phaser.Tilemap.TILED_JSON);

  //  The second parameter is the URL of the image (relative)
  game.load.image('warrior', 'assets/images/warrior.gif');

  game.load.image('stone', 'assets/images/stone.png');
  game.load.image('wood',  'assets/images/wood.png');
  game.load.image('door',  'assets/images/door.png');
  game.load.image('up',    'assets/images/up.png');
  game.load.image('down',  'assets/images/down.png');


}

function create() {

  map = game.add.tilemap('world');

  map.addTilesetImage('stone');
  map.addTilesetImage('wood');
  map.addTilesetImage('door');
  map.addTilesetImage('up');
  map.addTilesetImage('down');

  groundLayer = map.createLayer('ground');
  //groundLayer.debug = true;
  console.log("created map!");
  map.setCollisionByExclusion([1,3,4,5]); //#7, 32, 35, 36, 47]);

  groundLayer.resizeWorld();


  //  This creates a simple sprite that is using our loaded image and
  //  displays it on-screen
  warrior = game.add.sprite(400, 300, 'warrior');
  warrior.anchor.set(0.5);

  //hero_list.each({
   // create sprite for hero
  //});


  warrior.x = hero_x*32;
  warrior.y = hero_y*32;

  game.physics.enable(warrior);
  game.camera.follow(warrior);

  cursors = game.input.keyboard.createCursorKeys();


  // setup websockets
  console.log("setup websockets");

  ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
  ws.onopen    = function()  { console.log('websocket opened'); };
  ws.onclose   = function()  { console.log('websocket closed'); }
  ws.onmessage = function(m) { 
    console.log(m);

    message = JSON.parse(m.data);
    console.log('websocket message: ' +  message); 
    //console.log("my hero number: " + hero_id);
    //console.log("hero number sent: " + message.hero);

    if (message.hero == hero_id) {
      console.log("moving hero!");
      warrior.body.x = message.x * 32;
      warrior.body.y = message.y * 32;
    } else {
      console.log("updating other hero "+message.hero+"...");
      other_hero = _.detect(other_warriors, function(hero) { return hero.id == message.hero });
      if (other_hero) {
	console.log("already have this hero...");
	//_.select(other_warriors, function(hero) { hero.id == message.hero})
	other_hero.sprite.body.x = message.x * 32;
	other_hero.sprite.body.y = message.y * 32;
      } else {
	console.log("don't have this hero yet...");
	new_hero = game.add.sprite(message.x * 32, message.y * 32, 'warrior');
	game.physics.enable(new_hero);
	console.log("added sprite "+message.hero+" at "+message.x+", "+message.y);
	other_warriors.push({sprite: new_hero, id: message.hero}); //, x: message.x * 32, y: message.y * 32});
      }
      // update other warriors...
      console.log(other_warriors);
      //other_warriors[message.hero] = { x: message.x, y: message.y };
    }
  };
}

function update() {
  game.physics.arcade.collide(warrior, groundLayer);

  warrior.body.velocity.x = 0;
  warrior.body.velocity.y = 0;

  if (cursors.up.isDown)
  {
    //console.log("up");
    //# warrior.body.velocity.y = -200;
    //particleBurst();
    ws.send(JSON.stringify({hero: hero_id, move: 'north'})); //"moved up");

  }
  else if (cursors.down.isDown)
  {
    //console.log("down");
    //warrior.body.velocity.y = 200;
    // particleBurst();
    ws.send(JSON.stringify({hero: hero_id, move: 'south'})); //"moved down");
  }

  if (cursors.left.isDown)
  {
    //warrior.body.velocity.x = -200;
    warrior.scale.x = -1;

    ws.send(JSON.stringify({hero: hero_id, move: 'west'})); //"moved left");
    // particleBurst();
  }
  else if (cursors.right.isDown)
  {
    // warrior.body.velocity.x = 200;
    warrior.scale.x = 1;

    ws.send(JSON.stringify({hero: hero_id, move: 'east'})); //"moved right");
    //# particleBurst();
  }
}

function render() {

  //game.debug.body(warrior);
}
