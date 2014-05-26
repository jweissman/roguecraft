module Roguecraft
  class Game
    # include Navigation
    include Minotaur
    include Minotaur::Geometry
    include Minotaur::Geometry::Directions
    include Minotaur::Support::DirectionHelpers
    include Minotaur::Support::PositionHelpers

    # we're going to try to use TCOD's illumination algo server side...
    include TCOD

    DEFAULT_HEIGHT          = (ENV['GAME_HEIGHT'] || 30).to_i
    DEFAULT_WIDTH 	    = 50
    DEFAULT_ROOMS_PER_LEVEL = 8
    DEFAULT_DEPTH 	    = (ENV['GAME_DEPTH'] || 5).to_i
    DEFAULT_VISION_RADIUS   = 3

    # reactor interval (in s)
    TICK_INTERVAL = 0.1

    attr_reader :dungeon, :depth, :current_depth, :current_level, :heroes, :height, :width
    attr_accessor :gold, :potions, :next_moves, :scheduled_removals
    attr_accessor :entities
    
    def initialize(opts={})
      #puts " > Creating new game (#{Roguecraft.environment})..."

      # could just extend from a space?! :)
      @height        = opts[:height]  || DEFAULT_HEIGHT
      @width         = opts[:width]   || DEFAULT_WIDTH
      @depth         = opts[:depth]   || DEFAULT_DEPTH
    
      rooms_per_level = opts[:rooms_per_level] || DEFAULT_ROOMS_PER_LEVEL

      @heroes = []

      @dungeon       = opts[:dungeon]       || Dungeon.new(width: @width, height: @height, depth: @depth, room_count: rooms_per_level)

      @entities = @dungeon.entities.dup
      # create a stamp
      @entities.each { |lvl| lvl.each { |e| e.guid = SecureRandom.uuid }}

      @maps = []
      @next_moves = {}
      @scheduled_removals = []
    end

    def find_hero(uuid)
      @heroes.detect {|h| h.uuid == uuid }
    end

    def add_hero
      # puts "--- ADD HERO"
      position = find_type(0,0) # on level 0 with type 0/open
      hero = Hero.new(self, position: position, name: @dungeon.pc_name, vision_radius: DEFAULT_VISION_RADIUS)
      @heroes << hero
      puts "--- welcome #{hero.name} (#{hero.uuid})"
      
      hero.uuid
    end


    def map_for_level(level=0)
      @maps[level] ||= @dungeon.levels[level].to_a
    end

    
    def find_type(level,type)
      rows, columns = [], []
      x,y = nil,nil
      map_for_level(level).each_with_index do |row,_y|
	if row.any? { |tile| tile == type }
	  rows << _y
	end
      end

      y = rows.sample
      return false unless y 

      map_for_level(level)[y].each_with_index do |tile,_x| 
	if tile == type
	  columns << _x
	end
      end

      x = columns.sample

      return false unless x && y

      Position.new(x,y)
    #rescue
    #  binding.pry
    end


    def at(level,x,y)
      map_for_level(level)[y][x]
    end

    def entity_at(depth,x,y)
      @entities[depth].detect { |e| e.location.x == x && e.location.y == y }
    end

    def entity_at?(depth,x,y)
      !entity_at(depth,x,y).nil?
    end

    def floor?(depth,x,y);  at(depth,x,y) == 0 end
    def wall?(depth,x,y);   at(depth,x,y) == 1 end
    def door?(depth,x,y);   at(depth,x,y) == 2 end
    def up?(depth,x,y);     at(depth,x,y) == 3 end
    def down?(depth,x,y);   at(depth,x,y) == 4 end
    def stairs?(depth,x,y); up?(depth,x,y) || down?(depth,x,y) end 

    def gold?(depth,x,y)
      entity_at?(depth,x,y) && entity_at(depth,x,y).type == :gold
    end

    def gold(depth)
      @entities[depth].select { |e| e.type == :gold }
    end

    def potion?(depth,x,y)
      entity_at?(depth,x,y) && entity_at(depth,x,y).type == :potion
    end

    def potions(depth)
      @entities[depth].select { |e| e.type == :potion }
    end

    def scroll?(depth,x,y)
      entity_at?(depth,x,y) && entity_at(depth,x,y).type == :scroll
    end

    def scrolls(depth)
      @entities[depth].select { |e| e.type == :scroll }
    end

    def treasure?(depth,x,y)
      potion?(depth,x,y) || gold?(depth,x,y) || scroll?(depth,x,y)
    end
      # entity_at(depth,x,y)

    def block_visible?(depth,x,y)
      !(floor?(depth,x,y) || stairs?(depth,x,y)) # || treasure?(depth,x,y)
    end

    def next_move(entity,direction)
      @next_moves[entity] = direction
    end

    def remove(entity)
      @scheduled_removals << entity
    end

    # invoke move on entity unless blocked by map
    def move(entity, direction)
      entity.move(direction) if entity
    end

    def hero_position(hero_id)
      hero(hero_id).position
    end

    def down_stairs_position(level)
      stairs = find_type(level, 4)
      if stairs
	stairs
      else
	nil
      end
    end

    attr_accessor :sockets

    def sockets
      @sockets ||= {}
    end

    def transmit(type, message={}, target)
      message[:type] = type
      payload = message.to_json
      puts "==== SEND MESSAGE (type #{type}, length #{payload.size})"
      target.send(payload)
    end

    # kick core websocket gameplay loop
    def react!
      @started_at = Time.now
      EM.next_tick do 
	EM.add_periodic_timer(TICK_INTERVAL) do
	  @last_tick ||= 0
	  # puts "==== tick! last one was #{Time.now - @last_tick} ago"
	  @last_tick = Time.now

	  # moves = @next_moves
	  removals = @scheduled_removals.dup

	  removals.each do |entity|
	    entity_group = @entities.detect { |es| es.include?(entity) }

	    if entity_group
	      sockets.values.each do |s|
		data = {depth: @entities.index(entity_group), entity_id: entity.guid }
		transmit 'removal', data, s
	      end
	    end

	    puts ">>>> DELETING ENTITY"
	    entity_group.delete(entity) if entity_group
	    @scheduled_removals.delete(entity)

	    # recompute all fovs? (seems like we could at least limit to heroes on this level, but should really be a question of asking the heroes if the object is visible)
	    # timing of this could also be problematic

	    heroes.each { |h| h.build_fov_map }
	  end

	  # step!
	  @heroes.each { |h| h.update }

	  @next_moves.each do |entity, direction|
	    if move(entity, direction)
	      # entity.recompute_fov if entity.is_a?(Hero)
	      #   end
	      # end

	      # moves.each do |entity, _|
	      sockets.values.each do |s|
		if entity.is_a?(Roguecraft::Hero)
		  message_data = entity.attributes.merge({
		    visible:   entity.now_visible,
		    invisible: entity.now_invisible
		  })
		  puts "=== currently visible: #{entity.now_visible.inspect}"
		  transmit 'move', message_data, s
		end
	      end
	    end
	  end

	  @next_moves = {}
	end
      end
    end

    def processed_uuids
      @uuids_processed ||= []
    end

    def handle_request(socket)
      socket.onopen do
	# EM.defer do
	hero_id = add_hero
	hero = find_hero(hero_id) 
	hero.recompute_fov
	# puts "--- init hero! explored? #{hero.explored}"
	message_id = SecureRandom.uuid
	socket.send({type: 'init', message_id: message_id}.merge(hero.attributes.merge({visible: hero.now_visible})).to_json)
	sockets[hero_id] = socket
	# end
      end

      socket.onmessage do |msg|
	data = JSON.parse(msg)
	command = data['type']

	if processed_uuids.include?(data['message_id'])
	  puts "--- already processed"
	  return
	end
	processed_uuids << data['message_id'] if data['message_id']

	if command == 'move'
	  hero_id = data['id']
	  direction = direction_from_string(data['direction'])
	  next_move(find_hero(hero_id), direction) 
	elsif command == 'autopilot'
	  puts "==== autoexplore #{data['on']}"
	  hero_id = data['id']
	  hero = find_hero(hero_id)
	  hero.autoexplore(data['on'])
	else
	  raise "unknown message for command '#{command}'"
	end
      end

      socket.onclose do
	warn("websocket closed")
	hero_id = sockets.invert[socket]
	heroes.delete_if { |h| h.uuid == hero_id } 
	sockets.delete(hero_id)

	# let people know someone is gone...
	sockets.values.each do |s|
	  transmit 'bye', {id: hero_id}, s
	end
      end
    end

    def debug
      puts " > Current game uptime: #{Time.now - @started_at}"
      puts " > Player count: #{heroes.count}" 
    end
  end
end
