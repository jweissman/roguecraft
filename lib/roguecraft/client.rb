require 'json'
require 'eventmachine'
require 'websocket-eventmachine-client'
require 'pry'

module Roguecraft
  #
  #  wrapper around 
  #
  # class Model
  #   include ActiveModel::Serialization
  #   attr_accessor :attributes
  #   def initialize(attributes)
  #     @attributes = attributes
  #   end
  # end

  module WebClient
    def get_heroes
      puts "== GET /heroes"
      # @heroes ||= nil
      response = get '/heroes.json'
      # puts "--- sending heroes response: #{response.body}"
      # response = Net::HTTP.get(endpoint, "/heroes.json")
      # binding.pry
      JSON.parse(response.body).map do |h|
	OpenStruct.new(h)
      end
    end

    def get_entities
      puts "== GET /#{hero.depth}/entities.json"
      response = get("/#{hero.depth}/entities.json") # NET::HTTP.get(endpoint, "/#{hero}/entities.json")
      JSON.parse(response.body).map do |entity|
	OpenStruct.new(entity)
      end
    end

    def get_tiles #(hero)
      # @currentu
      # puts "--- get tiles!" 

      puts "=== GET /#{hero.depth}/tiles.json" rescue binding.pry
      # response = Net::HTTP.gee(endpoint, "/#{hero}/tiles.json")
      response = get("/#{hero.depth}/tiles.json") # NET::HTTP.get(endpoint, "/#{hero}/entities.json")
      tile_data = OpenStruct.new JSON.parse(response.body)
#      binding.pry
      tile_data
    end
    protected

    def get(uri)
      response = nil
      Net::HTTP.start(@server, @port) do |http|
	request = Net::HTTP::Get.new uri
	response = http.request request
      end
      response
    end


  end

  module WebsocketClient
    
    include Navigation
    include Minotaur::Support::DirectionHelpers

    def transmit(type, message)
      payload = {type: type}.merge(message).to_json
      # puts "=== TRANSMIT #{type}: #{payload}"
      @socket.send(payload)
    end

    # send hero move 'request' to server
    def move!(direction)
      # puts "--- sending move update for #{@hero_id}: in #{direction} from #{hero.x}, #{hero.y} at #{Time.now}"
      # @socket.send({type: 'move', 
      transmit 'move', id: @hero_id, direction: humanize_direction(direction)
    end

    def autopilot!(on=true)
      @autopilot_status ||= false

      # puts "== auto!"
      if @autopilot_status != on
	# @socket.send({type: 'autopilot', id: @hero_id, on: on}.to_json)
	transmit 'autopilot', id: @hero_id, on: on
	@autopilot_status = on
      end
    end

  end


  #  Base client class.
  #
  class Client
    include WebClient # API::Client
    include WebsocketClient 
    attr_accessor :bootstrap_complete

    def initialize(opts={})
      @server = opts.delete(:server) { 'localhost' }
      @port = opts.delete(:port) { 8181 }
    end

    def endpoint
      "#@server:#@port"
    end

    def entity_at(x,y)
      @entities.detect { |e| e.x == x && e.y == y }
    end

    def entity_at?(x,y)
      !entity_at(x, y).nil?
    end

    def width
      @tiles.width
    end

    def height
      @tiles.height
    end

    def plot
      # binding.pry
      tiles.data
    end

    def tiles
      # binding.pry
      @tiles ||= get_tiles #(@hero_id)
    end

    def heroes
      @heroes ||= get_heroes
    end

    def find_hero_by_id(uuid)
      heroes.detect { |h| h.id == uuid }
    end

    def hero
      @hero ||= find_hero_by_id(@hero_id) #heroes.detect { |h| h.id == @hero_id }
    end

    def entities
      @entities ||= get_entities
    end

    # def explored
    #   @explored ||= [
    # end

    # def explore!(x,y)
    #   explored[y] ||= []
    #   explored[y][x] = true
    # end

    def explored?(x,y)
      @explored_memo ||= {}
      #@explored_memo[y] ||= []
      @explored_memo[[x,y]] ||= hero.explored.include?([x,y])
      # explored[y][x] #.include?([x,y])
    end

    ###
    #
    # from console...

    def depth
      hero.depth
    end

    def block_visible?(x,y)
      !floor?(x,y)
    end

    def wall?(x,y)
      plot[y][x] == 2 
    end

    def up?(x,y) 
      plot[y][x] == 4
    end

    def down?(x,y)
      plot[y][x] == 5
    end

    def floor?(x,y)
      plot[y][x] == 1
    end

    def stairs?(x,y)
      up?(x,y) || down?(x,y)
    end

    def door?(x,y)
      plot[y][x] == 3
    end

    def gold?(x,y)
      has_gold = entity_at?(x,y) && entity_at(x,y).type == 'gold'
      has_gold
    end

    
    def potion?(x,y)
      has_potion = entity_at?(x,y) && entity_at(x,y).type == 'potion'
      has_potion
    end

    def scroll?(x,y)
      has_scroll = entity_at?(x,y) && entity_at(x,y).type == 'scroll'
      has_scroll
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


    # def get_vision
    #   puts "=== GET /#{hero.id}/vision.json" rescue binding.pry
    #   response = get("/#{hero.id}/vision.json")
    #   vision_data = OpenStruct.new JSON.parse(response.body)
    #   hero.explored = vision_data.explored
    #   hero.visible  = vision_data.visible
    # end

    ## game management stuff

    def setup_hero(opts={})
      @hero_id = opts.delete('id') { raise 'no id provided for hero setup' }
      puts "--- i am hero #{hero.name} with id #{hero.id} at depth #{hero.depth}"
	    hero.visible   ||= []
	    hero.visible     = hero.visible + opts['visible'] #hero_attributes.visible #- hero_attributes.invisible

	    # hero.explored  ||= []
	    hero.explored    = hero.visible # .explored + opts['visible']
      # request things
      heroes; tiles; entities

      true
    end

    # send hero move 'request' to server
    # def move!(direction)
    #   # puts "--- sending move update for #{@hero_id}: in #{direction} from #{hero.x}, #{hero.y} at #{Time.now}"
    #   @socket.send({type: 'move', id: @hero_id, direction: humanize_direction(direction)}.to_json)
    # end

    # def autopilot!(on=true)
    #   @autopilot_status ||= false

    #   # puts "== auto!"
    #   if @autopilot_status != on
    #     @socket.send({type: 'autopilot', id: @hero_id, on: on}.to_json)
    #     @autopilot_status = on
    #   end
    # end

    ####
    #
    # passing around app ... hm.
    def handle_message(app, msg)
      # puts "==== HANDLE MESSAGE #{msg}"
      message = msg
      case message['type']
      when 'init' then setup_hero(message) && bootstrap! # && core_loop
      when 'removal' then
	entity_id = message['id']
	entity_depth = message['depth']
	if entity_depth == depth
	  @entities.delete_at(entity_id)
	end
      when 'move' then
	hero_attributes = OpenStruct.new(message)
	# puts "--- hero attributes: #{hero_attributes.inspect}"
	h = find_hero_by_id(hero_attributes.id) 

	# rethink this madness?
	unless h 
	  h = hero_attributes
	end

	old_depth = hero.depth

	# ?
	h.x    = hero_attributes.x #(message)
	h.y    = hero_attributes.y #(message)
	h.depth = hero_attributes.depth
	h.gold = hero_attributes.gold
	#h.invisible = hero_attributes.invisible
	h.visible   ||= []
	h.visible     = (h.visible + hero_attributes.visible - hero_attributes.invisible).uniq

	h.explored  ||= []
	h.explored    = (h.explored + h.visible).uniq

	@heroes << h unless @heroes.map(&:id).include?(h.id)


	if h.id == hero.id
	  # puts "IT IS ME"
	  if old_depth != hero.depth
	    # puts "I WENT DOWNSTAIRS LET US GET THE TILES AGAIN!"
	    @tiles = get_tiles
	    @entities = get_entities
	    hero.explored = h.visible
	    @explored_memo = {} #[]
	    app.reflow!
	    # puts "GOT TILES?"
	  end
	end
	app.recompute! # = true
      else raise "--- unknown message type #{msg['type']}"
      end
    end

    def bootstrap_complete?
      @bootstrap_complete ||= false
    end

    def bootstrap!
      @bootstrap_complete = true
    end

    def react!
      puts "-- kicking reactor"
      EventMachine.add_periodic_timer(0.001) do
	# @last_tick ||= 0
	# puts "==== tick! last one was #{Time.now - @last_tick} ago"
	# @last_tick = Time.now
	EventMachine.stop if bootstrap_complete? && @reactor_block.call(self)
      end
    end

    # run core reactor loop...
    def react(app, &blk)
      @reactor_block = blk

      EM.run do
	# EM.set_quantum(10)
	Signal.trap("INT")  { EventMachine.stop }
	Signal.trap("TERM") { EventMachine.stop }
	ws = WebSocket::EventMachine::Client.connect(:uri => "ws://#{endpoint}")
	puts "--- starting websocket"

	ws.onopen do
	  puts "=== ws connected!"
	end

	ws.onmessage do |msg|
	  message = JSON.parse(msg)
	  handle_message(app,message)
	end

	ws.onclose do
	  puts "Disconnected"
	  puts "--- but we're not done? hmm"
	  EventMachine.stop
	end

	@socket = ws

	react!
      end
    end
  end  
end
