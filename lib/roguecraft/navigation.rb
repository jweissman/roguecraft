module Roguecraft
  module Navigation
    DIRECTIONS={ up: [0,-1], down: [0,1], left: [-1,0], right: [1,0] }

    def translate(position, direction)
      position.zip(DIRECTIONS[direction]).map { |a,b| a + b }
    end
  end
end
