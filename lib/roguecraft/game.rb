module Roguecraft
  class Game
    include Navigation
    attr_reader :depth, :current_level, :hero
    # attr_accessor :hero, :current_level
    def initialize(opts={})
      @height        = opts[:height] || 80
      @width         = opts[:width] || 50
      @hero          = opts[:hero] || Hero.new
      @dungeon       = opts[:dungeon] || Dungeon.new(width: @width, height: @height)

      @depth = 0
      row_with_floors = current_level.map.select { |row| row.any? { |tile| tile.floor? } }.sample
      open_position = row_with_floors.select { |tile| tile.floor? }.sample
      

      @hero.position = [ open_position.y, open_position.x ] #[0], open_position[1] ]

    end

    def current_level
      @dungeon.levels[@depth]
    end

    # invoke move on entity unless blocked by map
    def move(entity, direction)
      # binding.pry
      moved = false
      next_position = translate(entity.position, direction)
      tile = current_level.map[next_position[0]][next_position[1]]

      if tile.stair?
	descend! if entity == @hero && tile.down?
	moved = true
      end

      unless tile.blocked?
	entity.move(direction)
	moved = true
      end
      moved
    end

    def automove
      move(@hero, %i[ up down left right ].sample)
      # puts '--- would be automoving hero towards stairs on this floor'
      # row_with_up_stairs = current_level.map.detect { |row| row.any? { |tile| tile.stair? && tile.down? } }
      # stair = row_with_up_stairs.detect { |tile| tile.stair? && tile.down? }
      # model_level = @dungeon.model.levels[@depth]
      # if model_level.path_between?(Minotaur::Geometry::Position.new(@hero.x, @hero.y), Minotaur::Geometry::Position.new(stair.x, stair.y))
      #   next_position = model_level.solution_path.first
      #   @hero.x = next_position.x # = model_level.solution_path.first
      #   @hero.y = next_position.y
      # else
      #   puts "--- no path available!"
      # end
    end

    def descend!
      @depth = @depth - 1 
      row_with_up_stairs = current_level.map.detect { |row| row.any? { |tile| tile.stair? && tile.up? } }
      up_stairs_position = row_with_up_stairs.detect { |tile| tile.stair? && tile.up? }
      @hero.position = [ up_stairs_position.y, up_stairs_position.x ]
    end
  end
end
