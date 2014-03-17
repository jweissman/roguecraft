module Roguecraft
  class Entity
    include Navigation
    attr_accessor :position

    def initialize(opts={})
      @positions = opts[:position] || [0,0]
    end

    def move(direction)
      raise Exception.new("invalid direction") unless DIRECTIONS.keys.include?(direction)
      @position = translate(@position, direction) # zip(DIRECTIONS[direction]).map { |a,b| a + b }
    end

    def x; @position[0] end
    def y; @position[1] end

  end
end
