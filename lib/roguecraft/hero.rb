module Roguecraft
  
  class Hero < Entity
    include TCOD
    include Navigation
    include Minotaur::Support::DirectionHelpers
    include Minotaur::Support::PositionHelpers

    attr_accessor :name, :explored, :visible
    attr_reader :hp, :str, :con, :dex, :wis

    attr_accessor :gold

    def initialize(game, opts={})
      puts "-- creating hero with opts #{opts.inspect}"
      @hp = 30
      @str = @con = @dex = @wis = 10

      @torch_radius = opts.delete(:vision_radius) { 3 }
      @game = game
      @explored = []
      @visible  = []

      @maps = Array.new(@game.depth) {nil}

      @gold = 0

      super(opts)
    end

    def to_s
      "The hero #@name"
    end

    def attributes
      { :id => @uuid, :hp => @hp, :x => x, :y => y, :depth => depth, :gold => @gold } #, :visible => @visible, :explored => @explored }
    end

    def explore!(x,y)
      @explored ||= []
      @explored << [x,y]
      @explored.uniq!
    end

    def explored?(x,y)
      @explored ||= []
      @explored.include?([x,y])
    end

    def view!(x,y)
      explore!(x,y)

      @visible ||= []
      @visible << [x,y]
      @visible.uniq!
    end

    def visible?(x,y)
      @visible ||= []
      @visible.include?([x,y])
    end

    def build_fov_map
      puts "--- building hero fov map !!!!!"
      @maps[depth] = map_new @game.width, @game.height
      @game.map_for_level(depth).each_with_index do |row, y|
	row.each_with_index do |tile, x|
	  map_set_properties(@maps[depth], x, y, !@game.block_visible?(depth,x,y), !@game.wall?(depth,x,y))
	end
      end
      @maps[depth]
    end

    attr_reader :now_visible, :now_invisible
    def recompute_fov(changed_depths = false)
      puts "--- recompute hero fov !!!!!!!!"
      light_walls = true
      fov_algo = 0 

      @maps[depth] ||= build_fov_map
      
      map_compute_fov(@maps[depth], x, y, @torch_radius, light_walls, fov_algo)

      old_visible = @visible
      @visible = []
      @game.dungeon.levels[depth].each_position do |pos|
	view!(pos.x,pos.y) if map_is_in_fov(@maps[depth], pos.x, pos.y)
	#   visible!(x,y) 
	#   explore!(x,y) 
	# end
      end

      # compute the delta
      @now_visible   = changed_depths ? @visible : @visible - old_visible
      @now_invisible = old_visible - @visible # - @now_visible
    end

    def current_level
      @game.dungeon.levels[depth]
    end

    def current_room
      current_level.rooms.detect { |room| room.contains?(@position) }
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
      moved = false
      target = @position.translate(direction)
      x,y = target.x, target.y
      changed_depths = false
      if @game.stairs?(depth, x, y)
	if @game.up?(depth, x, y)
	  ascend!
	  changed_depths = true
	elsif @game.down?(depth, x, y)
	  descend!
	  changed_depths = true
	end
	moved = true
      end

      if @game.entity_at?(@current_depth, x, y)
	entity = @game.entity_at(depth, x, y) # @current_depth, x, y)
	if entity.type == :gold
	  @gold = @gold + entity.amount
	  @game.remove(entity)
	elsif entity.type == :potion || entity.type == :scroll
	  puts ">>> WOULD BE TAKING POTION/SCROLL"
	  @game.remove(entity)
	end
      end

      unless moved || @game.wall?(depth, x, y)
	super(direction)
	#@now_visible = @visible if changed_depths
	moved = true
      end

      recompute_fov(changed_depths) if moved
      
      # puts "moved? #{moved}"

      moved
    end

    def descend!
      puts ">>>>> DESCEND"
      @explored = []
      @current_depth = @current_depth + 1
      @automove_path = []
      stairs = @game.find_type(@current_depth, 3)
      @position = current_level.passable_adjacent_to(stairs).sample
      @autoexplore_target = nil
    end

    def ascend!
      puts ">>>>> ASCEND"
      @explored = []
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
	@game.next_move(self,next_direction)
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

    def visible_gold
      @game.gold(depth).select do |entity|
	explored?(entity.location.x, entity.location.y)
      end
    end

    def visible_potions
      @game.potions(depth).select { |e| explored?(e.location.x, e.location.y) }
    end

    def visible_scrolls
      @game.scrolls(depth).select { |e| explored?(e.location.x, e.location.y) }
    end

    def visible_treasure
      visible_gold + visible_potions + visible_scrolls
    end

    def current_level_has_visible_gold?
      visible_gold.count > 0
    end

    def current_level_has_visible_potions?
      visible_potions.count > 0
    end

    def current_level_has_visible_scrolls?
      visible_scrolls.count > 0
    end

    def current_level_has_visible_treasure?
      current_level_has_visible_gold? || current_level_has_visible_potions? || current_level_has_visible_scrolls?
    end

    def update
      autoexplore if @autoexplore_active
    end

    # follow a space-filling curve..?
    def autoexplore(on=true)
      if !on
	@autoexplore_active = false
	return
      end

      # puts "--- autoexploring"
      @autoexplore_active = true
      @autoexplore_target ||= nil
      if !@autoexplore_target || @autoexplore_target == @position # hero_position # || (current_room && explored?(@autoexplore_target.x, @autoexplore_target.y))
	puts "--- re-evaluating autoexplore target"

	if current_level_has_visible_treasure?
	  # SEEK THE GOLD

	  # visible_gold = @game.gold(depth).select do |gp| #entities[depth].select do |entity|
	  #   # entity.type == :gold && 
	  #   explored?(entity.location.x, entity.location.y)
	  # end

	  target_treasure = visible_treasure.min_by { |gp| distance_between(@position, gp.location) }
	  @autoexplore_target = target_treasure.location

        elsif current_room_has_unexplored_areas?
	  puts "--- still has unexplored areas"
          proposed_autoexplore_target = unexplored_areas_in_current_room.sample 
	  unless current_room.contains?(proposed_autoexplore_target) # @autoexplore_target
	    proposed_autoexplore_target = current_level.accessible_surrounding(proposed_autoexplore_target).select { |p| current_room.contains?(p) }.sample
	    # binding.pry unless proposed_autoexplore_target

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
