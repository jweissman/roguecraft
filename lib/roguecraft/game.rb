module Roguecraft
  class Game
    include Navigation
    include Minotaur
    include Minotaur::Geometry::Directions
    include Minotaur::Support::DirectionHelpers

    DEFAULT_HEIGHT          = 80
    DEFAULT_WIDTH 	    = 50
    DEFAULT_ROOMS_PER_LEVEL = 20
    DEFAULT_DEPTH 	    = 10

    attr_reader :dungeon, :depth, :current_depth, :current_level, :hero, :height, :width
    
    def initialize(opts={})
      @height        = opts[:height]  || 80
      @width         = opts[:width]   || 50
      @depth         = opts[:depth]   || DEFAULT_DEPTH
    
      rooms_per_level = opts[:rooms_per_level] || DEFAULT_ROOMS_PER_LEVEL

      @hero          = opts[:hero]    || Hero.new
      @dungeon       = opts[:dungeon] || Dungeon.new(width: @width, height: @height, depth: @depth, room_count: rooms_per_level)
      @current_depth = 0
      
      @hero.position = find_type(0)
      @explored = Array.new(@depth) { Array.new(@height) { Array.new(@width) { false }}}
    end

    def explore!(x,y)
      @explored[@current_depth][y][x] = true
    end

    def explored?(x,y)
      @explored[@current_depth][y][x]
    end

    def find_type(type)
      x,y = 0,0

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

      [x,y]
    end

    def current_level
      @dungeon.levels[@current_depth]
    end

    def map
      @map ||= current_level.to_a
    end

    def at(x,y)
      map[y][x]
    end

    def floor?(x,y);  at(x,y) == 0 end
    def wall?(x,y);   at(x,y) == 1 end
    def door?(x,y);   at(x,y) == 2 end
    def up?(x,y);     at(x,y) == 3 end
    def down?(x,y);   at(x,y) == 4 end
    def stairs?(x,y); up?(x,y) || down?(x,y) end 
    
    def block_visible?(x,y)
      wall?(x,y) || door?(x,y)
    end

    # invoke move on entity unless blocked by map
    def move(entity, direction)
      # binding.pry
      moved = false
      x, y = translate(entity.position, direction)
      
      # tile = current_level.map[next_position[0]][next_position[1]]

      if stairs?(x,y)
	if entity == @hero && up?(x,y) # next_position.x, next_position.y) #tile.up?(x,y)
	  ascend! 
	elsif entity == @hero && down?(x,y) # next_position.x, next_position.y) #tile.down?
	  descend! 
	end
	moved = true
      end

      unless moved || wall?(x,y) #tile.blocked?
	entity.move(direction)
	moved = true
      end

     #  @calculated_automove_path = false if entity == @hero

      moved
    end

    # def path_to_stairs #   @path ||= [] #   return unless @path.empty?
    # end

    # def path_to_stairs_from(x,y)
    #  #  @paths ||= {}
    #  #  return @paths["#{x},#{y}"] unless @paths["#{x},#{y}"].nil?
    #   row_with_down_stairs = current_level.map.detect { |row| row.any? { |tile| tile.stair? && tile.down? } }
    #   stair = row_with_down_stairs.detect { |tile| tile.stair? && tile.down? }
    #   model_level = @dungeon.model.levels[@depth]
    #   hero_pos = Minotaur::Geometry::Position.new(@hero.x, @hero.y)
    #   stair_pos = Minotaur::Geometry::Position.new(stair.x, stair.y)
    #   path = model_level.path(hero_pos, stair_pos) #Minotaur::Geometry::Position.new(@hero.x, @hero.y), Minotaur::Geometry::Position.new(stair.x, stair.y))
    #   binding.pry
    #   # @paths["#{x},#{y}"] = path
    #   path
    # end

    def hero_position
      Minotaur::Geometry::Position.new(@hero.x, @hero.y)
    end

    def path_to_stairs
      stairs = find_type 4
      stair_pos = Minotaur::Geometry::Position.new(stairs[0], stairs[1])
      hero_pos  = hero_position # Minotaur::Geometry::Position.new(@hero.x, @hero.y)
      current_level.path(hero_pos, stair_pos)
    end

    # TODO fix this madness!
    def compass_to_direction(direction)
      case direction
      when NORTH then :up # :left # :up
      when SOUTH then :down # :right # :down
      when EAST then  :right # :up # :right
      when WEST then  :left # :down # :left
      end
    end

    def automove
      # @calculated_automove_path ||= false
      # unless @calculated_automove_path
      #   puts "--- calculating automove path"
      #   @automove_path = path_to_stairs_from(@hero.x, @hero.y)
      #   puts "--- done!"
      #   @automove_index = 0
      # end

      # move(@hero, %i[ up down left right ].sample)
      puts '--- would be automoving hero towards stairs on this floor'
      @automove_path  ||= [] #path_to_stairs
      @automove_index ||= 0

      unless @automove_path.include?(hero_position)
	@automove_path = path_to_stairs 
      end
      
      @automove_index = @automove_path.index(hero_position)

      if @automove_index < @automove_path.size-1
	# binding.pry
	next_direction = direction_from(@automove_path[@automove_index], @automove_path[@automove_index+1])
	move(@hero, compass_to_direction(next_direction))
	explore!(@hero.x, @hero.y) #hero_position.x, hero_position.y)
      else
	puts "--- guess we couldn't find a path"
	# binding.pry
      end

      # stairs = find_type 4
      # stair_pos = Minotaur::Geometry::Position.new(stairs[0], stairs[0])
      # hero_pos  = Minotaur::Geometry::Position.new(@hero.x, @hero.y)
      # path = current_level.path(hero_pos, stair_pos)

      # next_position = path[1]
      # @hero.position = [next_position.x, next_position.y]

      # row_with_down_stairs = current_level.map.detect { |row| row.any? { |tile| tile.stair? && tile.down? } }
      # stair = row_with_down_stairs.detect { |tile| tile.stair? && tile.down? }
      # model_level = @dungeon.model.levels[@depth]
      # return 

      # path = path_to_stairs_from(@hero.x, @hero.y) # model_level.shortest_path(Minotaur::Geometry::Position.new(@hero.x, @hero.y), Minotaur::Geometry::Position.new(stair.x, stair.y))

      # unless path.empty?
      #   puts "--- moving!"
      #   next_position = path[1]
      #   binding.pry
      #   # next_position = @automove_path[@automove_index] # model_level.solution_path[1] #.first
      #   # @automove_index = @automove_index + 1
      #   @hero.position = [next_position.x, next_position.y]
      #   # @hero.x = next_position.x # = model_level.solution_path.first
      #   # @hero.y = next_position.y
      # end
    end

    def descend!
      puts "--- descending from level #@current_depth"
      @current_depth = @current_depth + 1
      @map = current_level.to_a
      @automove_path = []
      stairs = find_type(3)
      puts "--- now on level #@current_depth at stairs: #{stairs}"
      @hero.position     =  current_level.passable_adjacent_to(Minotaur::Geometry::Position.new(stairs[0],stairs[1])).sample # stairs
    end

    def ascend!
      puts "--- ascending from level #@current_depth"
      @current_depth = @current_depth - 1 
      @map = current_level.to_a
      @automove_path = []
      stairs = find_type(4)
      puts "--- now on level #@current_depth at stairs: #{stairs}"
      @hero.position  	   = current_level.passable_adjacent_to(Minotaur::Geometry::Position.new(stairs[0],stairs[1])).sample
    end
  end
end
