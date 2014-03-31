module Roguecraft
  class Entity
    include Minotaur::Geometry
    include Navigation

    # hmm, might as well start using 3d positions...?
    attr_accessor :position
    attr_accessor :current_depth

    def initialize(opts={})
      @position = opts[:position] || Position.new(0,0) # [0,0]
      @current_depth = 0
    end

    def move(direction)
      # raise Exception.new("invalid direction") unless DIRECTIONS.keys.include?(direction)
      @position = @position.translate(direction) # compass_to_direction(direction)) # , direction) # zip(DIRECTIONS[direction]).map { |a,b| a + b }
    end

    def x; @position.x end
    def y; @position.y end
    # def position
    #   @position ||= [0,0]
    # end

    # def x; position[0] end
    # def y; position[1] end
    def x=(_x); position.x = _x end
    def y=(_y); position.y = _y end
  end
end
