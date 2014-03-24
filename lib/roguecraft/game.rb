module Roguecraft
  class Game
    include Navigation
    include Minotaur
    include Minotaur::Geometry
    include Minotaur::Geometry::Directions
    include Minotaur::Support::DirectionHelpers
    include Minotaur::Support::PositionHelpers

    DEFAULT_HEIGHT          = 80
    DEFAULT_WIDTH 	    = 50
    DEFAULT_ROOMS_PER_LEVEL = 10
    DEFAULT_DEPTH 	    = 3

    DEFAULT_VISION_RADIUS   = 4

    attr_reader :dungeon, :depth, :current_depth, :current_level, :hero, :height, :width
    attr_reader :gold
    
    def initialize(opts={})
      @height        = opts[:height]  || 80
      @width         = opts[:width]   || 50
      @depth         = opts[:depth]   || DEFAULT_DEPTH
    
      rooms_per_level = opts[:rooms_per_level] || DEFAULT_ROOMS_PER_LEVEL

      @hero          = opts[:hero]          || Hero.new
      @vision_radius = opts[:vision_radius] || DEFAULT_VISION_RADIUS
      @dungeon       = opts[:dungeon]       || Dungeon.new(width: @width, height: @height, depth: @depth, room_count: rooms_per_level)

      @current_depth = 0
      
      @hero.position = find_type(0)

      # @accessible = Array.new(@depth) { Array.new(@height) { Array.new(@width) { @dungeon.levels[
      @explored   = Array.new(@depth) { Array.new(@height) { Array.new(@width) { false }}}
      @unexplored = Array.new(@depth) { Array.new(@height) { Array.new(@width) { true }}}

      # clone entities... we'll need to remove them, move them around, etc.
      @entities = @dungeon.entities.dup
    end

    def explore!(x,y)
      @explored[@current_depth][y][x] = true
    end

    def explored?(x,y)
      @explored[@current_depth][y][x]
    end

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

    def find_type(type)
      x,y = nil,nil
      map.each_with_index do |row,_y|
	if row.any? { |tile| tile == type }
	  y = _y
	  break
	end
      end

      map[y].each_with_index do |tile,_x| 
	if tile == type
	  x = _x
	  break
	end
      end

      return false unless x && y
      [x,y]
    end

    def current_level
      @dungeon.levels[@current_depth]
    end

    def current_room
      current_level.rooms.detect do |room|
	room.contains?(hero_position)
      end
    end

    # def adjacent_rooms
    #   current_room.adjacent_rooms
    # end

    def unexplored_rooms
      current_level.rooms.select do |room|
	room.all_positions.any? { |pos| !explored?(pos.x,pos.y) } #unexplored.include?([pos.x, pos.y]) }
      end
    end

    def find_nearest_unexplored_room(source=current_room)
      puts "find nearest unexplored..."
      @tested_for_unexplored ||= []
      @tested_for_unexplored << source
      unexplored_adjacent = source.adjacent_rooms.detect { |room| unexplored_rooms.include?(room) }
      if unexplored_adjacent
	return unexplored_adjacent
      else
	source.adjacent_rooms.each do |room|
	  unless @tested_for_unexplored.include?(room)
	    unexplored_room = find_nearest_unexplored_room(room)
	    if unexplored_room
	      return unexplored_room
	    end
	  end
	end
      end

      nil
    end

    def map
      @map ||= current_level.to_a
    end

    def at(x,y)
      map[y][x]
    end

    def entity_at(x,y)
      @entities[@current_depth].detect { |e| e.location.x == x && e.location.y == y }
    end

    def entity_at?(x,y)
      !entity_at(x,y).nil?
    end

    def floor?(x,y);  at(x,y) == 0 end
    def wall?(x,y);   at(x,y) == 1 end
    def door?(x,y);   at(x,y) == 2 end
    def up?(x,y);     at(x,y) == 3 end
    def down?(x,y);   at(x,y) == 4 end
    def stairs?(x,y); up?(x,y) || down?(x,y) end 

    def gold?(x,y)
      entity_at?(x,y) && entity_at(x,y).type == :gold
    end
    
    def block_visible?(x,y)
      !floor?(x,y) # wall?(x,y) || door?(x,y) || stairs?(x,y)
    end

    # invoke move on entity unless blocked by map
    def move(entity, direction)
      moved = false
      x, y = translate(entity.position, direction)
      
      if stairs?(x,y)
	if entity == @hero && up?(x,y)
	  ascend! 
	elsif entity == @hero && down?(x,y)
	  descend! 
	end
	moved = true
      end

      if entity_at?(x,y)
	if entity_at(x,y).type == :gold
	  # collect gold!
	  @gold ||= 0
	  @gold = @gold + entity_at(x,y).amount
	  @entities[@current_depth] -= [entity_at(x,y)]
	end
      end

      unless moved || wall?(x,y)
	entity.move(direction)
	moved = true
      end

      moved
    end

    def hero_position
      Minotaur::Geometry::Position.new(@hero.x, @hero.y)
    end

    def path_to(target)
      current_level.path(hero_position, target)
    end

    def down_stairs_position
      stairs = find_type 4
      if stairs
	Position.new(stairs[0], stairs[1])
      else
	nil
      end
    end

    # TODO fix this madness!
    def compass_to_direction(direction)
      case direction
      when NORTH then :up
      when SOUTH then :down
      when EAST then  :right
      when WEST then  :left
      end
    end

    def automove(target) #=down_stairs_position)
      @automove_path  ||= []
      @automove_index ||= 0

      unless @automove_path.include?(hero_position) && @automove_path.last == target
	@automove_path = path_to(target)
      end
      
      @automove_index = @automove_path.index(hero_position)

      if @automove_index < @automove_path.size-1
	next_direction = direction_from(@automove_path[@automove_index], @automove_path[@automove_index+1])
	move(@hero, compass_to_direction(next_direction))
      else
	puts "--- !!!! guess we couldn't find a path"
	binding.pry
      end
    end

    def unexplored_areas_in_current_room
      (current_room.all_positions + current_room.outer_perimeter + current_room.outer_corners).select { |p| !explored?(p.x, p.y) }
    end

    def current_room_has_unexplored_areas?
      !unexplored_areas_in_current_room.empty?
    end

    def current_level_has_visible_gold?
      @entities[@current_depth].any? do |entity|
	entity.type == :gold && explored?(entity.location.x, entity.location.y)
      end
    end

    # follow a space-filling curve..?
    def autoexplore
      puts "--- autoexploring"
      @autoexplore_target ||= nil
      if !@autoexplore_target || @autoexplore_target == hero_position # || (current_room && explored?(@autoexplore_target.x, @autoexplore_target.y))
	puts "--- re-evaluating autoexplore target"

	if current_level_has_visible_gold?
	  # SEEK THE GOLD

	  visible_gold = @entities[@current_depth].select do |entity|
	    entity.type == :gold && explored?(entity.location.x, entity.location.y)
	  end

	  target_gold = visible_gold.min_by { |gp| distance_between(hero_position, gp.location) }
	  @autoexplore_target = target_gold.location

        elsif current_room_has_unexplored_areas?
	  puts "--- still has unexplored areas"
          proposed_autoexplore_target = unexplored_areas_in_current_room.sample 
	  unless current_room.contains?(proposed_autoexplore_target) # @autoexplore_target
	    proposed_autoexplore_target = current_level.accessible_surrounding(proposed_autoexplore_target).select { |p| current_room.contains?(p) }.sample
	    binding.pry unless proposed_autoexplore_target

	  end

	  @autoexplore_target = proposed_autoexplore_target
	else
	  puts "--- no unexplored areas left in this room"
	  @tested_for_unexplored = []
	  nearest_unexplored_room = find_nearest_unexplored_room
	  if nearest_unexplored_room
	    @autoexplore_target = nearest_unexplored_room.center # unexplored_rooms.first.center
	  else
	    @autoexplore_target = down_stairs_position || nil
	  end
        end
      end

      automove(@autoexplore_target) if @autoexplore_target
    end

    def descend!
      @current_depth = @current_depth + 1
      @map = current_level.to_a
      @automove_path = []
      stairs = find_type(3)
      @hero.position     =  current_level.passable_adjacent_to(Position.new(stairs[0],stairs[1])).sample # stairs
      @autoexplore_target = nil
    end

    def ascend!
      @current_depth = @current_depth - 1 
      @map = current_level.to_a
      @automove_path = []
      stairs = find_type(4)
      @hero.position  	   = current_level.passable_adjacent_to(Position.new(stairs[0],stairs[1])).sample
    end
  end
end
