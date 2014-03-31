require 'json'
require 'eventmachine'
require 'websocket-eventmachine-client'
require 'pry'

module Roguecraft
  class Client
    include Minotaur::Support::DirectionHelpers
    def initialize(opts={})
      @server = opts.delete(:server) { 'localhost' }
      @port = opts.delete(:port) { 8181 }
      # puts "--- establishing connection to local rogue server..."
      # TODO Net::HTTP.get('localhost:8181', '/games.json')
      # doesn't exist yet :)
      #  Net::HTTP.start(uri.host, uri.port) do |http|
      #      request = Net::HTTP::Get.new uri
      #
      #          response = http.request request # Net::HTTPResponse object
      #            endz1

      # there should be at least one game going... connect to it?
      # @hero_id = nil
      # @heroes = []
      # puts "i am hero #{hero.id}"
    end

    def endpoint
      "#@server:#@port"
    end

    def get(uri)
      response = nil
      Net::HTTP.start(@server, @port) do |http|
	request = Net::HTTP::Get.new uri
	response = http.request request # Net::HTTPResponse object
	#yield response
      end
      response
    end


    def entity_at(x,y)
      @entities.detect { |e| e.x == x && e.y == y }
    end

    def entity_at?(x,y)
      !entity_at(x,y).nil?
    end

    def width
      @tiles.width
    end

    def height
      @tiles.height
    end

    def map
      @tiles.data
    end

    def tiles
      @tiles ||= get_tiles(@hero_id)
    end

    def heroes
      @heroes ||= get_heroes
    end

    def hero
      heroes[@hero_id]
    end

    def entities
      @entities ||= get_entities
    end

    ###
    #
    # from console...

    def depth
      hero.depth
    end

    # def hero
    #   @hero ||= @game.add_hero # game.hero
    # end
    def block_visible?(x,y)
      # @game.block_visible?(depth, x, y)
      !floor?(x,y)
    end

    def wall?(x,y)
      # @game.wall?(depth, x, y)
      map[y][x] == 2 
    end

    def up?(x,y) 
      # @game.up?(depth,x,y)
      map[y][x] == 4

    end

    def down?(x,y)
      map[y][x] == 5
      # @game.down?(depth,x,y)
    end

    def floor?(x,y)
      map[y][x] == 1
    end

    def stairs?(x,y)
      up?(x,y) || down?(x,y)
      # @game.stairs?(depth, x, y)
    end

    def door?(x,y)
      map[y][x] == 3
      # @game.door?(depth, x, y)
    end

    def gold?(x,y)
      # @game.gold?(depth, x, y)
      entity_at?(x,y) && entity_at(x,y).type == :gold
    end

    def each_position
      0.upto(height-1) do |y|
	0.upto(width-1) do |x|
	  yield [x,y]
	end
      end
    end

    # def put_hero
    # end

    def get_tiles(hero)
      # @currentu
      puts "--- get tiles!" 

      # response = Net::HTTP.gee(endpoint, "/#{hero}/tiles.json")
      response = get("/#{@hero_id}/tiles.json") # NET::HTTP.get(endpoint, "/#{hero}/entities.json")
      OpenStruct.new JSON.parse(response.body)
    end

    def get_heroes
      # @heroes ||= nil
      response = get '/heroes.json'
      puts "--- sending heroes response: #{response.body}"
      # response = Net::HTTP.get(endpoint, "/heroes.json")
      JSON.parse(response.body).map do |hero|
	OpenStruct.new(hero)
      end
    end

    def get_entities
      response = get("/#{@hero_id}/entities.json") # NET::HTTP.get(endpoint, "/#{hero}/entities.json")
      JSON.parse(response.body).map do |entity|
	OpenStruct.new(entity)
      end
    end

    def setup_hero(opts={})
      puts "-- setup hero with opts #{opts}"
      @hero_id = opts.delete('hero_id') { raise 'no id provided for hero setup' }
      puts "--- i am hero #{hero.name}"


      # request things
      heroes; tiles; entities

      true
    end

    # send hero move 'request' to server
    def move!(direction)
      # # hero = find_hero(@hero_id)
      # new_position = Minotaur::Geometry::Position.new(hero.x, hero.y).translate(direction)
      # hero.x = new_position.x
      # hero.y = new_position.y
      

      @socket.send({type: 'move', id: @hero_id, direction: humanize_direction(direction)}.to_json)
    end

    def explore!(cells=[])
      @socket.send({type: 'explore', id: @hero_id, cells: cells}.to_json)
    end

    ####
    #

    # run core reactor loop...
    def react
      puts "-- kicking reactor"
      EM.run do


	Signal.trap("INT")  { EventMachine.stop }
	Signal.trap("TERM") { EventMachine.stop }
	ws = WebSocket::EventMachine::Client.connect(:uri => "ws://#{endpoint}")
	puts "--- starting websocket"
	# EM::WebSocket.start(:host => @server, :port => @port) do |ws|
	ws.onopen do
	  puts "Connected!"
	  # EventMachine.next_tick do
	  #   puts "--- get server datas..."
	  #   # ws.send "Hello Server!"
	  #   # ws.send({type: 'client-ping', id: @hero_id}.to_json)

	  #   
	  # end
	end

	ws.onmessage do |msg, type|
	  puts "Received message: #{msg}!"
	  puts "--- message is of type (?) #{type}"
	  message = JSON.parse(msg)
	  case message['type']
	  when 'init' then setup_hero(message) && EventMachine.add_periodic_timer(0.01) do
	      EventMachine.stop if yield(self)
	    end# puts "--- init hero!"
	  when 'move' then
	    puts "--- a hero moved!"
	    hero_id = message['hero_id']
	    puts "--- attempting to move #{hero_id}"
	    x,y = message['x'], message['y']
	    @heroes[hero_id] ||= OpenStruct.new
	    @heroes[hero_id].x = x # message['x']
	    @heroes[hero_id].y = y # message['y']
	    @heroes[hero_id].explored = message['explored']
	    puts "--- moved"
	    p @heroes[hero_id].x #inspect
	    p @heroes[hero_id].y #inspect

	    # hero = find_hero(hero_id)
	  else puts "--- unknown message type #{msg['type']}"
	  end
	end

	ws.onclose do
	  puts "Disconnected"
	  puts "--- but we're not done? hmm"
	  EventMachine.stop
	end


	@socket = ws


      end
    end
  end  
end
