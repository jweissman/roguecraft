module Roguecraft
  class Entity
    include Navigation
    attr_accessor :position

    def initialize(opts={})
      @position = opts[:position] || [0,0]
    end

    def move(direction)
      raise Exception.new("invalid direction") unless DIRECTIONS.keys.include?(direction)
      @position = translate(@position, direction) # zip(DIRECTIONS[direction]).map { |a,b| a + b }
    end

    # def x; @position[0] end
    # def y; @position[1] end
    def position
      @position ||= [0,0]
    end

    def x; position[0] end
    def y; position[1] end
    def x=(_x); position[0] = _x end
    def y=(_y); position[1] = _y end
  end
end
