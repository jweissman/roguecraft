module Roguecraft
  class Hero < Entity
    include Minotaur::Support::DirectionHelpers
    include Minotaur::Support::PositionHelpers
    attr_reader :name, :explored
    attr_accessor :gold

    attr_reader :hp, :str, :con, :dex, :wis
    # attr_accessor :position

    def initialize(game, opts={})
      
      @hp = 30
      @str = @con = @dex = @wis = 10

      @current_depth = 0

      @game = game # dungeon
      @explored = Array.new(@game.depth) { Array.new(@game.height) { Array.new(@game.width) { false }}}
      open_space = @game.find_type(@current_depth, 0) # find open floorspace...
      # position = Position.new(open_space[0], open_space[1])

      @gold = 0

      @name = @game.dungeon.pc_name # generate(:name)

      super(opts.merge(position: open_space))
      # @dungeon.heroes << self 
    end

    def depth
      @current_depth
    end

    def explore!(x,y)
      @explored[depth][y][x] = true
    end

    def explored?(x,y)
      @explored[depth][y][x]
    end

    def current_level
      @game.dungeon.levels[depth]
    end

    def current_room
      current_level.rooms.detect { |room| room.contains?(@position) }
    end

    def explore!(x,y)
      @explored[@current_depth][y][x] = true
    end

    def explored?(x,y)
      @explored[@current_depth][y][x]
    end

    def unexplored_rooms
      current_level.rooms.select do |room|
	room.all_positions.any? { |p| !explored?(p.x,p.y) }
      end
    end

    def nearest_unexplored_room(source=current_room)
      @tested_for_unexplored ||= []
      @tested_for_unexplored << source

      unexplored_adjacent = source.adjacent_rooms.detect do |room| 
	unexplored_rooms.include?(room)
      end

      if unexplored_adjacent
	return unexplored_adjacent
      else
	source.adjacent_rooms.each do |room|
	  unless @tested_for_unexplored.include?(room)
	    unexplored_room = nearest_unexplored_room(room)
	    if unexplored_room
	      return unexplored_room
	    end
	  end
	end
      end

      nil
    end

    def move(direction)
      puts "--- attempting to move hero #{humanize_direction(direction)}!!!"
      # could move stair/gold collection here?
      moved = false
      target = @position.translate(direction)
      x,y = target.x, target.y
      if @game.stairs?(@current_depth, x, y)
	if @game.up?(@current_depth, x, y)
	  ascend!
	elsif @game.down?(@current_depth, x, y)
	  descend!
	end
	moved = true
      end

      if @game.entity_at?(@current_depth, x, y)
	entity = @game.entity_at(@current_depth, x, y)
	if entity.type == :gold
	  @gold = @gold + entity.amount
	  @game.entities[@current_depth] -= [entity]
	end
      end

      unless moved || @game.wall?(@current_depth, x, y)
	super(direction)
	moved = true
      end
      
      puts "moved? #{moved}"

      # actually translate
      # super(direction)
      moved
    end

    def descend!
      @current_depth = @current_depth + 1
      @automove_path = []
      stairs = @game.find_type(@current_depth, 3)
      @position = current_level.passable_adjacent_to(stairs).sample # Position.new(stairs[0], stairs[1])).sample
      @autoexplore_target = nil
    end

    def ascend!
      @current_depth = @current_depth - 1
      @automove_path = []
      stairs = @game.find_type(@current_depth, 4)
      @position = current_level.passable_adjacent_to(Position.new(stairs[0], stairs[1])).sample
    end


    def path_to(target)
      current_level.path(@position, target)
    end

    def automove(target)
      @automove_path ||= []
      @automove_index ||= 0

      unless @automove_path.include?(@position) && @automove_path.last == target
	@automove_path = path_to(target)
      end

      @automove_index = @automove_path.index(@position)

      if @automove_index < @automove_path.size - 1
	next_direction = direction_from(@automove_path[@automove_index], @automove_path[@automove_index+1])
	move((next_direction))
      else
	puts "=== COULD NOT FIND A PATH!!!"
      end
    end

    def unexplored_areas_in_current_room
      (current_room.all_positions + current_room.outer_perimeter + current_room.outer_corners).select { |p| !explored?(p.x, p.y) }
    end

    def current_room_has_unexplored_areas?
      !unexplored_areas_in_current_room.empty?
    end

    def current_level_has_visible_gold?
      @game.entities[@current_depth].any? do |entity|
	entity.type == :gold && explored?(entity.location.x, entity.location.y)
      end
    end

    # follow a space-filling curve..?
    def autoexplore
      puts "--- autoexploring"
      @autoexplore_target ||= nil
      if !@autoexplore_target || @autoexplore_target == @position # hero_position # || (current_room && explored?(@autoexplore_target.x, @autoexplore_target.y))
	puts "--- re-evaluating autoexplore target"

	if current_level_has_visible_gold?
	  # SEEK THE GOLD

	  visible_gold = @game.entities[@current_depth].select do |entity|
	    entity.type == :gold && explored?(entity.location.x, entity.location.y)
	  end

	  target_gold = visible_gold.min_by { |gp| distance_between(@position, gp.location) }
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
	  next_room = nearest_unexplored_room
	  if next_room
	    @autoexplore_target = next_room.center # unexplored_rooms.first.center
	  else
	    @autoexplore_target = @game.down_stairs_position(@current_depth) || nil
	  end
        end
      end

      automove(@autoexplore_target) if @autoexplore_target
    end
    # DIRECTIONS={ up: [0,-1], down: [0,1], left: [-1,0], right: [1,0] }

    # def move(direction)
    #   raise Exception.new("invalid direction") unless DIRECTIONS.keys.include?(direction)
    #   @position = @position.zip(DIRECTIONS[direction]).map { |a,b| a + b }
    # end

    # def position
    #   @position ||= [0,0]
    # end

    # def x; position[0] end
    # def y; position[1] end
    # def x=(_x); position[0] = x end
    # def y=(_y); position[1] = y end
  end
end
