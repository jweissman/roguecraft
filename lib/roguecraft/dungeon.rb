module Roguecraft
  class Dungeon
    DEFAULT_WIDTH = 80
    DEFAULT_HEIGHT = 50

    class Room; end

    class Secret; end
    class Trap; end
    class Treasure; end
    class Enemy; end

    class Tile
      attr_reader :x, :y
      # attr_reader :blocked, :block_visibility
      # attr_accessor :explored #, :block_visibility #, :doorway, :stair_up, :stair_down

      def initialize(x,y)
	@x = x
	@y = y
	@explored = false
      end
      # def initialize(opts={})
      #   @blocked  = opts[:blocked]  || false
      #   @explored = opts[:explored] || false
      #   @block_visiblity = opts[:block_visibility] || false
      # end

      def explored?; @explored end

      def explore!
	@explored = true
      end

      def blocked?; false end
      def block_visibility?; false end

      def floor?; false end
      def wall?;  false end
      def stair?; false end
      def door?;  false end
    end

    # open floor
    class Floor < Tile
      def blocked?; false end
      def block_visibility?; false end
      def floor?; true end
    end

    class Wall < Tile
      def blocked?; true end
      def block_visibility?; true end
      def wall?; true end
    end

    class Doorway < Tile
      def blocked?; false end
      def block_visibility?; true end
      def door?; true end
    end

    UP = 1
    DOWN = 2
    class Stairwell < Tile
      def initialize(x,y,access)
	super(x,y)
	@access = access
      end
      def blocked?; false end
      def block_visibility?; true end
      def stair?; true end
      def up?; @access == UP end
      def down?; @access == DOWN end
    end

    class Level
      include Minotaur
      attr_accessor :map
      def initialize(labyrinth) #opts={}) #depth=0)
	# @width = opts[:width] || DEFAULT_WIDTH
	# @height = opts[:height] || DEFAULT_HEIGHT

	# @grid = Labyrinth.new height: @width, width: @height, extruder: Minotaur::Extruders::AssemblingRoomExtruder, serializer: Minotaur::Serializers::CompactArraySerializer
	# @grid.extrude!
	
	@grid = labyrinth
	# binding.pry
	@map = []
	@grid.to_a.each_with_index do |row, y|
	  row_elements = []
	  row.each_with_index do |tile, x|
	    row_elements << case tile
	    when 1 then Wall.new(x,y)
	    when 2 then Doorway.new(x,y)
	    when 3,4 then Stairwell.new(x,y,tile == 3 ? UP : DOWN)
	    else Floor.new(x,y)
	    end
	  end
	  @map << row_elements
	end
      end 

      def rooms; Array.new(2) { Room.new } end
      def secrets; Array.new(2) { Secret.new } end
      def traps; Array.new(2) { Trap.new } end
      def treasure; Array.new(2) { Treasure.new } end
      def enemies; Array.new(2) { Enemy.new } end
    end

    # def levels; Array.new(1) { |i| Level.new(depth: i) } end
    attr_reader :levels, :model
    def initialize(opts={})
      @width  = opts[:width]  || DEFAULT_WIDTH
      @height = opts[:height] || DEFAULT_HEIGHT

      @model  = Minotaur::Dungeon.new(width: @width, height: @height)
      @levels = @model.levels.map do |labyrinth|
	Level.new(labyrinth)
      end

      # @levels = Array.new(3) { |i| Level.new({depth: i, width: @width, height: @height}) }
    end
  end
end
