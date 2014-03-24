var game = new Phaser.Game(800, 600, Phaser.CANVAS, 'phaser-example', { preload: preload, create: create, update: update, render: render });
var map;
var groundLayer;
var warrior;

function preload() {
    game.load.tilemap('world', 'http://localhost:8181/map.json', null, Phaser.Tilemap.TILED_JSON);
    //  The second parameter is the URL of the image (relative)
    game.load.image('warrior', 'assets/images/warrior.gif');

    game.load.image('stone',      'assets/images/stone.png');
    game.load.image('wood',       'assets/images/wood.png');
    game.load.image('door',       'assets/images/door.png');
    game.load.image('upstairs',   'assets/images/up.png');
    game.load.image('downstairs', 'assets/images/down.png');


}

function create() {
    game.stage.backgroundColor = "#000000";
    map = game.add.tilemap('world');

    map.addTilesetImage('stone');
    map.addTilesetImage('wood');
    map.addTilesetImage('door');
    map.addTilesetImage('upstairs');
    map.addTilesetImage('downstairs');
   
    groundLayer = map.createLayer('ground');
    //groundLayer.debug = true;
    console.log("created map!");
    map.setCollisionByExclusion([1,3,4,5]); //#7, 32, 35, 36, 47]);
    groundLayer.resizeWorld();


    //  This creates a simple sprite that is using our loaded image and
    //  displays it on-screen
    warrior = game.add.sprite(400, 300, 'warrior');
    warrior.anchor.set(0.5);
    
    game.physics.enable(warrior);
    game.camera.follow(warrior);

    cursors = game.input.keyboard.createCursorKeys();
}

function update() {
    game.physics.arcade.collide(warrior, groundLayer);

    warrior.body.velocity.x = 0;
    warrior.body.velocity.y = 0;

    if (cursors.up.isDown)
    {
      //console.log("up");
        warrior.body.velocity.y = -200;
        //particleBurst();
    }
    else if (cursors.down.isDown)
    {
      //console.log("down");
        warrior.body.velocity.y = 200;
        // particleBurst();
    }

    if (cursors.left.isDown)
    {
        warrior.body.velocity.x = -200;
        warrior.scale.x = -1;
        // particleBurst();
    }
    else if (cursors.right.isDown)
    {
        warrior.body.velocity.x = 200;
        warrior.scale.x = 1;
        //# particleBurst();
    }
}

function render() {

  //game.debug.body(warrior);
}
