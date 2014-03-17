module Roguecraft
  class Hero < Entity
    attr_reader :hp, :str, :con, :dex, :wis
    # attr_accessor :position

    def initialize
      @hp = 30
      @str = @con = @dex = @wis = 10
    end

    # DIRECTIONS={ up: [0,-1], down: [0,1], left: [-1,0], right: [1,0] }

    # def move(direction)
    #   raise Exception.new("invalid direction") unless DIRECTIONS.keys.include?(direction)
    #   @position = @position.zip(DIRECTIONS[direction]).map { |a,b| a + b }
    # end

    # def x; @position[0] end
    # def y; @position[1] end
  end
end
