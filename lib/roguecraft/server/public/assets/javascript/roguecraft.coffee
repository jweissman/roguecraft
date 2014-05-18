###
a barebones js roguecraft client
###
preload = ->
  console.log "preload (COFFEE)"
  game.stage.disableVisibilityChange = true
  game.stage.backgroundColor = "#000000"
  
  # todo figure out how to load more as needed... -- may just need to do game 'phases'...
  d = 0

  while d < 15
    game.load.tilemap "level" + d, d + "/tilemap.json", null, Phaser.Tilemap.TILED_JSON
    d++
  
  #game.load.tilemap('entities'+d, d+'/entities.json', null, Phaser.Tilemap.TILED_JSON);
  # load treasure etc? :)
  #game.load.text('entities'+d, d+'/entities.json')
  game.load.image "warrior", "assets/images/warrior.gif"
  game.load.image "stone", "assets/images/stone.png"
  game.load.image "wood", "assets/images/wood.png"
  game.load.image "door", "assets/images/door.png"
  game.load.image "up", "assets/images/up.png"
  game.load.image "down", "assets/images/down.png"
  game.load.image "gold", "assets/images/gold.png"
  return
createMap = ->
  console.log "create map"
  groundLayer.destroy()  if groundLayer
  map = game.add.tilemap("level" + depth)
  map.addTilesetImage "stone"
  map.addTilesetImage "wood"
  map.addTilesetImage "door"
  map.addTilesetImage "up"
  map.addTilesetImage "down"
  obscure()
  groundLayer = map.createLayer("ground")
  groundLayer.resizeWorld()
  text = "level: " + depth
  style =
    font: "65px Arial"
    fill: "#ff0044"
    align: "center"

  levelText.destroy()  if levelText
  levelText = game.add.text(300, 400, text, style)
  levelText.fixedToCamera = true
  return

#graphics = game.add.graphics(0,0);
#graphics.clear();
setupRealm = ->
  console.log "setup realm"
  createMap()
  createWarrior()
  return
obscure = ->
  console.log "OBSCURE"
  map.forEach (tile) ->
    tile.alpha = 0
    return

  return

# moveHero(x,y) takes map (**tile**) coordinates
moveHero = (x, y) ->
  console.log "move hero to " + x + "," + y + "!"
  warrior.body.x = x * 32
  warrior.body.y = y * 32
  return
handleMessage = (m) ->
  console.log "handle message"
  message = JSON.parse(m.data)
  command = message.type
  forMe = message.id is hero_id
  differentDepth = message.depth isnt depth
  console.log "COMMAND RECEIVED: " + command + " (for me? " + forMe + ", different depth? " + differentDepth + ")"
  console.log "--- visible: "
  console.log message.visible
  if command is "move"
    if forMe
      if differentDepth
        console.log "CHANGE OF DEPTH DETECTED"
        depth = message.depth
        setupRealm()
      recalcObscured message.visible
      moveHero message.x, message.y
    else
      other_hero = _.detect(other_warriors, (hero) ->
        hero.id is message.id
      )
      if other_hero
        other_hero.sprite.body.x = message.x * 32
        other_hero.sprite.body.y = message.y * 32
        
        #other_hero.depth = message.depth;
        if differentDepth #message.depth == depth) {
          other_hero.sprite.alpha = 0
        else
          other_hero.sprite.alpha = 1
      else
        new_hero = game.add.sprite(message.x * 32, message.y * 32, "warrior")
        game.physics.enable new_hero
        other_warriors.push #, depth: message.depth});
          sprite: new_hero
          id: message.id

  else if command is "init"
    hero_id = message.id
    setupRealm()
    recalcObscured message.visible
    moveHero message.x, message.y
  else if command = "bye"
    console.log "LATER"
    other_hero = _.detect(other_warriors, (hero) ->
      hero.id is message.id
    )
    if other_hero
      console.log "DESTROY"
      other_hero.sprite.destroy() #alpha = 0;
      other_warriors = _.without(other_warriors, other_hero) #_.isEqual(other_hero)) // function(hero) { return hero.id == message.id });
      console.log "--- hero_idother players connected: " + other_warriors.length
  return
createSockets = ->
  console.log "setup sockets"
  ws = new WebSocket("ws://" + window.location.host + window.location.pathname)
  ws.onopen = ->
    console.log "websocket opened"
    return

  ws.onclose = ->
    console.log "websocket closed"
    return

  ws.onmessage = handleMessage # function(m) {
  return
recalcObscured = (newVisible) ->
  console.log "recalc obscured"
  _.each newVisible, (position) ->
    x = position[0]
    y = position[1]
    tile = map.getTile(x, y, groundLayer)
    unless tile.alpha is 1
      console.log "making visible!"
      tile.alpha = 1 #.0;
      groundLayer.dirty = true
    return

  return
createWarrior = ->
  console.log "create warrior"
  warrior.destroy()  if warrior
  
  #if (warrior) { warrior.alpha = 0; }// = null;
  #other_warriors = new Array();
  warrior = game.add.sprite(400, 300, "warrior")
  warrior.anchor.set 0.5
  
  #}
  game.physics.enable warrior
  game.camera.follow warrior
  return
create = ->
  console.log "#create"
  cursors = game.input.keyboard.createCursorKeys()
  
  # setup websockets
  console.log "setup websockets"
  createSockets()
  return
handleCursors = ->
  move = false
  direction = ""
  if cursors.up.isDown
    move = true
    direction = "north"
  else if cursors.down.isDown
    move = true
    direction = "south"
  else if cursors.left.isDown
    warrior.scale.x = -1
    move = true
    direction = "west"
  else if cursors.right.isDown
    warrior.scale.x = 1
    move = true
    direction = "east"
  if move
    console.log "move " + direction
    ws.send JSON.stringify(
      type: "move"
      id: hero_id
      direction: direction
    )
  return
update = ->
  
  #game.physics.arcade.collide(warrior, groundLayer);
  handleCursors()
  return
render = ->
game = new Phaser.Game(800, 600, Phaser.AUTO, "roguecraft",
  preload: preload
  create: create
  update: update
  render: render
)
map = undefined
groundLayer = undefined
fogLayer = undefined
warrior = undefined
other_warriors = new Array()
treasure = new Array()
graphics = undefined
ws = undefined
cursors = undefined
hero_id = undefined
depth = 0
levelText = undefined

#if (warrior) { game.debug.body(warrior); }
