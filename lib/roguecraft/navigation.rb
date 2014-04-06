module Roguecraft
  # handle fov, autoexplore on behalf of entities
  module Navigation

    # attr_accessor :explored, :visible

    # def explored
    #   @explored ||= []
    # end

    # def visible
    #   @visible ||= []
    # end

    # def fov_maps
    #   @fov_maps ||= Array.new(@game.depth) {[]}
    # end


    def depth
      @current_depth
    end

    # def explored
    #   @explored ||= Array.new(@game.depth) { Array.new(@game.height) { Array.new(@game.width) { false }}}
    # end

    # def visible
    #   @visible ||= Array.new(@game.depth) {[]}
    # end




    # DIRECTIONS={ up: [0,-1], down: [0,1], left: [-1,0], right: [1,0] }

    # def translate(position, direction)
    #   position.zip(DIRECTIONS[direction]).map { |a,b| a + b }
    # end

    # def compass_to_direction(direction)
    #   case direction
    #   when NORTH then :up
    #   when SOUTH then :down
    #   when EAST then  :right
    #   when WEST then  :left
    #   end
    # end

    # def direction_to_compass


  end
end
