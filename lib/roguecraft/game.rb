module Roguecraft
  class Game
    include Navigation
    include Minotaur
    include Minotaur::Geometry
    include Minotaur::Geometry::Directions
    include Minotaur::Support::DirectionHelpers
    include Minotaur::Support::PositionHelpers

    DEFAULT_HEIGHT          = 40
    DEFAULT_WIDTH 	    = 40
    DEFAULT_ROOMS_PER_LEVEL = 4
    DEFAULT_DEPTH 	    = 3

    DEFAULT_VISION_RADIUS   = 4

    attr_reader :dungeon, :depth, :current_depth, :current_level, :heroes, :height, :width
    attr_reader :gold, :next_moves

    attr_accessor :entities
    
    def initialize(opts={})
      @height        = opts[:height]  || DEFAULT_HEIGHT
      @width         = opts[:width]   || DEFAULT_WIDTH
      @depth         = opts[:depth]   || DEFAULT_DEPTH
    
      rooms_per_level = opts[:rooms_per_level] || DEFAULT_ROOMS_PER_LEVEL

      # @hero          = opts[:hero]          || Hero.new
      @heroes = []

      @vision_radius = opts[:vision_radius] || DEFAULT_VISION_RADIUS
      @dungeon       = opts[:dungeon]       || Dungeon.new(width: @width, height: @height, depth: @depth, room_count: rooms_per_level)

      # @current_depth = 0
      
       
      # @accessible = Array.new(@depth) { Array.new(@height) { Array.new(@width) { @dungeon.levels[
      # @explored   = [] # Array.new {Array.new(@depth) { Array.new(@height) { Array.new(@width) { false }}}}
      # @unexplored = [] # Array.new { Array.new(@depth) { Array.new(@height) { Array.new(@width) { true }}}}
       
      # clone entities... we'll need to remove them, move them around, etc.
      @entities = @dungeon.entities.dup
      @maps = [] #Array.new(@depth) {[]}
      @next_moves = {}
    end

    def add_hero
      hero = Hero.new(self) #, position: find_type(0))
      # hero.position = find_type(0)
      @heroes << hero
      
      hero_id = @heroes.index(hero)

      # @explored[hero_id] = Array.new(@depth) { Array.new(@height) { Array.new(@width) { false }}}
      # @unexplored[hero_id] = Array.new(@depth) { Array.new(@height) { Array.new(@width) { true }}}

      hero_id
    end


    def map_for_level(level=0)
      # binding.pry # unless level
      @maps[level] ||= @dungeon.levels[level].to_a
      # @dungeon.levels[@heroes[hero_id].current_depth]
    end


    # def explore!(hero_id,x,y)
    #   @explored[hero_id][@current_depth][y][x] = true
    # end

    # def explored?(hero_id,x,y)
    #   @explored[hero_id][@current_depth][y][x]
    # end

    # def unexplored
    #   unexplored = []
    #   @explored[@current_depth].each_with_index do |row, y|
    #     row.each_with_index do |is_explored, x|
    #       position = Minotaur::Geometry::Position.new(x,y)
    #       unexplored << [x,y] if !is_explored && current_level.accessible?(position)
    #     end
    #   end
    #   unexplored
    # end

    def find_type(level,type)
      rows, columns = [], []
      x,y = nil,nil
      map_for_level(level).each_with_index do |row,_y|
	if row.any? { |tile| tile == type }
	  rows << _y
	  # y = _y
	  # break
	end
      end

      y = rows.sample

      map_for_level(level)[y].each_with_index do |tile,_x| 
	if tile == type
	  # x = _x
	  columns << _x
	  # break
	end
      end

      x = columns.sample

      return false unless x && y

      Position.new(x,y)
    rescue
      binding.pry
    end

    def hero(id)
      @heroes[hero_id]
    end

    def current_level(hero_id)
      @dungeon.levels[hero(hero_id).current_depth]
      # @dungeon.levels[@current_depth]
    end

    def current_room(hero_id)
      current_level(hero_id).rooms.detect do |room|
	room.contains?(hero(hero_id).position) # _position(hero_id))
      end
    end

    # def adjacent_rooms
    #   current_room.adjacent_rooms
    # end

    def unexplored_rooms(hero_id)
      current_level.rooms.select do |room|
	room.all_positions.any? { |pos| !explored?(pos.x,pos.y) } #unexplored.include?([pos.x, pos.y]) }
      end
    end

    def find_nearest_unexplored_room(hero_id,source) #=current_room)
      puts "find nearest unexplored..."
      @tested_for_unexplored ||= []
      @tested_for_unexplored << source

      unexplored_adjacent = source.adjacent_rooms.detect { |room| unexplored_rooms(hero_id).include?(room) }
      if unexplored_adjacent
	return unexplored_adjacent
      else
	source.adjacent_rooms.each do |room|
	  unless @tested_for_unexplored.include?(room)
	    unexplored_room = find_nearest_unexplored_room(hero_id,room)
	    if unexplored_room
	      return unexplored_room
	    end
	  end
	end
      end

      nil
    end

    # def map
    #   @map ||= current_level.to_a
    # end

    def at(level,x,y)
      map_for_level(level)[y][x]
    rescue
      binding.pry
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
    
    def block_visible?(depth,x,y)
      !floor?(depth,x,y) # wall?(x,y) || door?(x,y) || stairs?(x,y)
    end

    def next_move(entity,direction)
      puts "--- setting next moves!"
      #@next_moves ||= {}
      #binding.pry
      @next_moves[entity] = direction
    end
    
    def step!
      # apply next moves
      # puts "==== STEP!"
      # p @next_moves
      # binding.pry
      @next_moves.each do |entity, direction|
	puts ">>>> PROCESSING NEXT MOVE!!"
	move(entity, direction)
      end
      @next_moves = {}
    end

    # invoke move on entity unless blocked by map
    def move(entity, direction)
      entity.move(direction) if entity
      # moved = false
      # target = entity.position.translate(direction)
      # depth = entity.current_depth
      # 
      # # if stairs?(depth,x,y)
      # #   if entity.is_a?(Hero) && up?(depth,x,y) # == @hero && up?(x,y)
      # #     hero.ascend! 
      # #   elsif entity.is_a?(Hero) && down?(depth,x,y) # == @hero && down?(x,y)
      # #     hero.descend! 
      # #   end
      # #   moved = true
      # # end

      # # if entity_at?(depth,x,y)
      # #   if entity_at(depth,x,y).type == :gold
      # #     # collect gold!
      # #     # gold ||= 0
      # #     entity.gold = entity.gold + entity_at(x,y).amount
      # #     @entities[depth] -= [entity_at(x,y)]
      # #   end
      # # end

      # unless moved || wall?(depth,target.x,target.y)
      #   entity.move(direction)
      #   moved = true
      # end

      # moved
    end

    def hero_position(hero_id)
      hero(hero_id).position
      # Minotaur::Geometry::Position.new(@heroes[hero_id].x, @heroes[hero_id].y)
    end

    # def path(hero_id,target)
    #   current_level(hero_id).path(hero_position(hero_id), target) # @heroes[hero_id].position, target)
    # end

    def down_stairs_position(level)
      stairs = find_type(level, 4)
      if stairs
	# Position.new(stairs[0], stairs[1])
	stairs
      else
	nil
      end
    end

    # TODO fix this madness! (unify around directions, tile maps)
    # def automove(hero_id,target) #=down_stairs_position)
    #   @automove_path  ||= []
    #   @automove_index ||= 0

    #   unless @automove_path.include?(hero_position(hero_id)) && @automove_path.last == target
    #     @automove_path = path_to(target)
    #   end
    #   
    #   @automove_index = @automove_path.index(hero_position)

    #   if @automove_index < @automove_path.size-1
    #     next_direction = direction_from(@automove_path[@automove_index], @automove_path[@automove_index+1])
    #     move(@hero, compass_to_direction(next_direction))
    #   else
    #     puts "--- !!!! guess we couldn't find a path"
    #     binding.pry
    #   end
    # end

    # def unexplored_areas_in_current_room
    #   (current_room.all_positions + current_room.outer_perimeter + current_room.outer_corners).select { |p| !explored?(p.x, p.y) }
    # end

    # def current_room_has_unexplored_areas?
    #   !unexplored_areas_in_current_room.empty?
    # end

    # def current_level_has_visible_gold?
    #   @entities[@current_depth].any? do |entity|
    #     entity.type == :gold && explored?(entity.location.x, entity.location.y)
    #   end
    # end

    # follow a space-filling curve..?
    # def autoexplore
    #   puts "--- autoexploring"
    #   @autoexplore_target ||= nil
    #   if !@autoexplore_target || @autoexplore_target == hero_position # || (current_room && explored?(@autoexplore_target.x, @autoexplore_target.y))
    #     puts "--- re-evaluating autoexplore target"

    #     if current_level_has_visible_gold?
    #       # SEEK THE GOLD

    #       visible_gold = @entities[@current_depth].select do |entity|
    #         entity.type == :gold && explored?(entity.location.x, entity.location.y)
    #       end

    #       target_gold = visible_gold.min_by { |gp| distance_between(hero_position, gp.location) }
    #       @autoexplore_target = target_gold.location

    #     elsif current_room_has_unexplored_areas?
    #       puts "--- still has unexplored areas"
    #       proposed_autoexplore_target = unexplored_areas_in_current_room.sample 
    #       unless current_room.contains?(proposed_autoexplore_target) # @autoexplore_target
    #         proposed_autoexplore_target = current_level.accessible_surrounding(proposed_autoexplore_target).select { |p| current_room.contains?(p) }.sample
    #         binding.pry unless proposed_autoexplore_target

    #       end

    #       @autoexplore_target = proposed_autoexplore_target
    #     else
    #       puts "--- no unexplored areas left in this room"
    #       @tested_for_unexplored = []
    #       nearest_unexplored_room = find_nearest_unexplored_room
    #       if nearest_unexplored_room
    #         @autoexplore_target = nearest_unexplored_room.center # unexplored_rooms.first.center
    #       else
    #         @autoexplore_target = down_stairs_position || nil
    #       end
    #     end
    #   end

    #   automove(@autoexplore_target) if @autoexplore_target
    # end

    # def descend!
    #   @current_depth = @current_depth + 1
    #   @map = current_level.to_a
    #   @automove_path = []
    #   stairs = find_type(3)
    #   @hero.position     =  current_level.passable_adjacent_to(Position.new(stairs[0],stairs[1])).sample # stairs
    #   @autoexplore_target = nil
    # end

    # def ascend!
    #   @current_depth = @current_depth - 1 
    #   @map = current_level.to_a
    #   @automove_path = []
    #   stairs = find_type(4)
    #   @hero.position  	   = current_level.passable_adjacent_to(Position.new(stairs[0],stairs[1])).sample
    # end
  end
end
