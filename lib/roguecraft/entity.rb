module Roguecraft
  class Entity
    include Minotaur::Geometry
    include Navigation

    # hmm, might as well start using 3d positions...?
    attr_accessor :uuid
    attr_accessor :position
    attr_accessor :current_depth

    def initialize(opts={})
      @uuid = SecureRandom.uuid
      @current_depth = 0

      @name = opts.delete(:name) { 'unnamed' }
      @position = opts.delete(:position) { Position.new(0,0) } # [0,0]
    end

    def move(direction)
      @position = @position.translate(direction)
    end

    def x; @position.x end
    def y; @position.y end
    def x=(_x); position.x = _x end
    def y=(_y); position.y = _y end
  end
end
