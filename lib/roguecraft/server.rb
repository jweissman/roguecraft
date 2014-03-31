#
# TODO implement multiplay server..
#
require 'roguecraft'

require 'pry'
require 'sinatra/base'
require 'sinatra-websocket'
require 'json'

require 'eventmachine'
require 'sinatra/base'
require 'thin'


module Roguecraft
  module HeroesHelper
    def hero_attributes(game, hero)
      puts "#{hero.x}, #{hero.y}"
      { hero_id: game.heroes.index(hero), 
	x: hero.x, y: hero.y, 
	depth: hero.depth, 
	name: hero.name, 
	# depth: hero.current_depth, 
	explored: hero.explored[hero.depth] }
    end
  end


  module TilesHelper

    # def generate_hero_list(game)
    #   game.heroes.map do |hero|
    #     hero_attributes(game, hero)	
    #     # { hero_id: id, x: hero.x, y: hero.y, depth: hero.depth, name: hero.name }
    #   end
    # end
    #
    def generate_entities(level)
      game.entities[level].map do |e| #(&:to_h)
	{ type: e.type, amount: e.amount, x: e.location.x, y: e.location.y }
      end
    end


    def generate_tiles(level)
      @tiles ||= {}
      @tiles[level] ||= game.map_for_level(level).map { |r| r.map { |i| i+1 }}
    end

    def generate_phaser_tilemap(level)
      tilesets = { :wood => 1, :stone => 2, :door => 3, :up => 4, :down => 5 }
      @tilemaps ||= {}

      @tilemaps[level] ||= {
	version: 1,
	height: game.height,
	width:  game.width,
	orientation: 'orthogonal',
	properties: {},
	layers: [{
	  data: generate_tiles(game,level),  # game.map_for_level(0).flatten.map { |i| i+1 },
	  height: game.height,
	  width:  game.width,
	  name: 'ground',
	  opacity: 1,
	  type: 'tilelayer',
	  visible: true,
	  x: 0,
	  y: 0
        }], # .merge(generate_tiles(game,level))],

	tileheight: 32,
	tilewidth: 32, 

	tilesets: tilesets.map do |name, gid|
	  {
	    firstgid: gid,
	    image: "assets/images/#{name}.png",
	    imageheight: 32,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: name,
	    properties: {},
	    tilewidth: 32,
	    tileheight: 32
	  }
	end

	
      }.to_json
    end
  end

  # class WebsocketAPI
  #   def handle(msg)
  #   end
  # end
  
  # Our simple hello-world app
  class API < Sinatra::Base
    include Minotaur::Support::DirectionHelpers
    include Minotaur::Geometry
    include Minotaur::Geometry::Directions
    include HeroesHelper
    include TilesHelper

    # threaded - False: Will take requests on the reactor thread
    #            True:  Will queue request for background thread
    #


    # TODO need to handle multiple games!
    configure do
      set :threaded, false
      set :sockets, {} # []
      # oset :games, [ Roguecraf]
      #EM.defer do
      # @game = Game.new
      set :game, Game.new # Game.new
      # end


      settings.game.step! 
    end

    def game
      settings.game
    end


    def tick!

    end

    # def hero_attributes(hero)
    #   { hero_id: game.heroes.index(hero), 
    #     x: hero.x, y: hero.y, 
    #     depth: hero.depth, 
    #     name: hero.name, 
    #     # depth: hero.current_depth, 
    #     explored: hero.explored[hero.depth] }
    # end

    def find_hero(id)
      game.heroes[id.to_i] # .index(id)
    end

    def hero_id(hero)
      game.heroes.index(hero)
    end

    # Request runs on the reactor thread (with threaded set to false)
    get '/hello' do
      'Hello World'
    end

    # Request runs on the reactor thread (with threaded set to false)
    # and returns immediately. The deferred task does not delay the
    # response from the web-service.
    get '/delayed-hello' do
      EM.defer do
	sleep 5
      end
      'I\'m doing work in the background, but I am still free to take requests'
    end

    get '/heroes.json' do
      # generate_heroes_list(game).to_json
      settings.game.heroes.map do |hero|
	hero_attributes(settings.game, hero) # settings.hero)	
	# { hero_id: id, x: hero.x, y: hero.y, depth: hero.depth, name: hero.name }
      end.to_json
    end

    get '/:hero_id/entities.json' do
      hero = find_hero(params[:hero_id])
      generate_entities(hero.depth).to_json
    end

    get '/:hero_id/tiles.json' do
      hero = find_hero(params[:hero_id])
      {data: generate_tiles(hero.depth), width: settings.game.width, height: settings.game.height}.to_json
    end

    # TODO for different levels...
    #
    get '/:hero_id/tilemap.json' do
      # puts "--- render map..."
      hero = find_hero(params[:hero_id])
      generate_phaser_tiles(hero.depth).to_json
    end

    get '/' do
      # TODO ugh globals

      # @heroes = settings.game.heroes

      if !request.websocket?

	erb :index
      else
	# TODO add hero on ws open, remove on close?
	request.websocket do |ws|
	  ws.onopen do
	    # puts "=== ws connect"
	    # ws.send("Hello World!")
	    EM.defer do
	      hero_id = settings.game.add_hero
	      hero = settings.game.heroes[hero_id]
	      # puts "--- got hero: #{hero_id}"

	      # hero_name = settings.game.heroes[hero_id].name
	      # hero_position = settings.game.heroes[hero_id].position

	      # puts "--- sending hero init message"
	      ws.send({type: 'init'}.merge(hero_attributes(settings.game, hero)).to_json)
	      settings.sockets[hero_id] = ws
	    end
	    #       , 

	    # 	      name: hero_name, 
	    # 	      hero_id: hero_id, 
	    # 	      x: hero_position.x, 
	    # 	      y: hero_position.y})

	  end

	  ws.onmessage do |msg|
	    data = JSON.parse(msg)
	    # puts "--- got message data: #{data.inspect}"
	    if data['type'] == 'move'
	      hero_id = data['id']
	      direction = direction_from_string(data['direction'])

	      # hero = 
	      puts "--- moving hero #{hero_id} in direction #{direction}"

	      settings.game.next_move(settings.game.heroes[hero_id], direction)
	    elsif data['type'] == 'explore'
	      # puts "--- exploring area based on trusting client... :)" # a little broken but could be helpful to be able to disable on client side for debugging etc
	      hero_id = data['hero']
	      hero = find_hero(hero_id)
	      # binding.pry
	      for cell in data['cells'] 
		hero.explore!(cell[0], cell[1])
	      end

	      ws.send({type: 'move'}.merge(hero_attributes(settings.game, hero)).to_json) # rescue binding.pry #, hero: settings.game.heroes.index(entity), x: entity.x, y: entity.y}.to_json)

	    else
	      puts "--- got unknown message of type #{data['type']}"
	    end

	    # new_position = settings.game.heroes[hero_id].position
	    # puts "--- new position: #{new_position.to_s}"

	    #EM.next_tick do 
	    #  settings.sockets.each do |s| 
	    #    s.send({type: 'hero_move', hero: hero_id, x: new_position.x, y: new_position.y}.to_json)
	    #  end
	    #end
	  end

	  ws.onclose do
	    warn("websocket closed")

	    # delete this hero
	    hero_id = settings.sockets.invert[ws]
	    settings.game.heroes.delete_at(hero_id) # settings.sockets.invert[ws]) # _if { |hero| settings.game.heroes.index(hero) == settings.sockets.invert[ws] }
	    settings.sockets.delete(ws)
	  end
	end
      end
    end
  end
end

include Roguecraft::HeroesHelper
def run(opts)

  # Start the reactor
  EM.run do

    # define some defaults for our app
    server  = opts[:server] || 'thin'
    host    = opts[:host]   || '0.0.0.0'
    port    = opts[:port]   || '8181'
    web_app = opts[:app]

    # create a base-mapping that our application will set at. If I
    # have the following routes:
    #
    #   get '/hello' do
    #     'hello!'
    #   end
    #
    #   get '/goodbye' do
    #     'see ya later!'
    #   end
    #
    # Then I will get the following:
    #
    #   mapping: '/'
    #   routes:
    #     /hello
    #     /goodbye
    #
    #   mapping: '/api'
    #   routes:
    #     /api/hello
    #     /api/goodbye
    dispatch = Rack::Builder.app do
      map '/' do
	run web_app
      end
    end

    # NOTE that we have to use an EM-compatible web-server. There
    # might be more, but these are some that are currently available.
    unless ['thin', 'hatetepe', 'goliath'].include? server
      raise "Need an EM webserver, but #{server} isn't"
    end

    # Start the web server. Note that you are free to run other tasks
    # within your EM instance.
    Rack::Server.start({
      app:    dispatch,
      server: server,
      Host:   host,
      Port:   port
    })

    # web_app.step!

    EM.next_tick do 
      EM.add_periodic_timer(0.1) do
	# puts "--- tick!"
	# send out updates on *every* one?
	# settings.sockets.each do |s| 
		  moves = web_app.settings.game.next_moves
	  web_app.settings.game.step! # tick!
	  moves.each do |entity, _|
	    web_app.settings.sockets.values.each do |s| # heroes.each_with_index do |hero, id|
	      # hero = settings.game.heroes[id]
	      #for hero in settings.game.next_moves.keys # heroes 
	      # if hero moved last step?
	      #if settings.game.next_moves
	      # generate_hero_list(settings.game)
	      # puts "tick!"

	      puts ">> UPDATE EVERY SOCKET"
	      if entity.is_a?(Roguecraft::Hero)
		s.send({type: 'move'}.merge(hero_attributes(web_app.settings.game, entity)).to_json) # rescue binding.pry #, hero: settings.game.heroes.index(entity), x: entity.x, y: entity.y}.to_json)
	      end
	      # end
	    end
	    # end
	  end
      end
    end
    # puts "--- starting roguecraft game on server!"
    #$game = Roguecraft::Game.new
    # puts "--- done!"

    Signal.trap("INT")  { EventMachine.stop }
    Signal.trap("TERM") { EventMachine.stop }
  end
end

# start the application
# server = Roguecraft::Server.new
server = Roguecraft::API.new
run app: server # Roguecraft::API.new

