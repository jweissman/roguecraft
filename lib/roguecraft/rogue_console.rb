# require 'libtcod'
###
require 'pry'

class RogueConsole
  include Roguecraft
  include TCOD

  DEFAULT_WIDTH  = 60
  DEFAULT_HEIGHT = 45
  DEFAULT_FPS    = 20

  WALL_TILE = '#' # 256
  GROUND_TILE = '.'

  UPWARD_STAIR_TILE = '<'
  DOWNWARD_STAIR_TILE = '>'
  DOOR_TILE = '+'

  GROUND_COLOR = Color.rgb(77, 60, 41)

  def initialize(opts={})
    puts "--- console init!"
    @height = opts[:height] || DEFAULT_HEIGHT
    @width  = opts[:width]  || DEFAULT_WIDTH
    @fps    = opts[:fps]    || DEFAULT_FPS

    @game = Game.new(width: @width, height: @height)
    # @current_level = @dungeon.levels.first # .grid.to_a # lambda { @game.current_level }
    # @map = @current_level.map

    # @map = @current_level.map.each do |row|
    #   row.each do |blocked|
    #     Dungeon::Tile.new(blocked: blocked == 1)
    #   end
    # end

    @torch_radius = 30
    @light_walls = true
    @fov_algorithm = 0 # default algo...
    @recompute_fov = true

  end

  def current_level
    @game.current_level
  end

  def map
    current_level.map
  end

  def hero
    @game.hero
  end

  def build_fov_map
    puts "--- build FOV map!"
    @fov_map = map_new @width, @height

    0.upto(@height-1) do |y|
      0.upto(@width-1) do |x|
	tile = map[x][y]

	console_put_char(@console, x, y, ' '.ord, BKGND_NONE)
	map_set_properties @fov_map, x, y, !tile.block_visibility?, !tile.blocked? rescue binding.pry # !@current_level[x][y]
      end
    end

    console_flush

    # @dungeon = Dungeon.new
    # @hero    = Hero.new
    # @hero.position = [ @height/2, @width/2 ]
  end

  def launch!
    console_set_custom_font('arial10x10.png', FONT_TYPE_GREYSCALE | FONT_LAYOUT_TCOD, 0, 0)
    console_init_root(@width, @height, 'roguecraft!', false, RENDERER_SDL)
    sys_set_fps @fps # (LIMIT_FPS)

    @console = console_new(@width, @height)

    # console_map_ascii_codes_to_font(256, 32, 0, 5)

    build_fov_map
    run_forever
  end

  def handle_keys
    key = console_wait_for_keypress(true)  #turn-based

    if key.vk == KEY_ENTER && key.lalt
      #Alt+Enter: toggle fullscreen
      console_set_fullscreen(!console_is_fullscreen())
    elsif key.vk == KEY_ESCAPE
      return true  #exit game
    end

    #movement keys
    old_depth = @game.depth
    if console_is_key_pressed(KEY_UP) || key.c == 'k' 
      @recompute_fov = true if @game.move(hero, :up)
      # $playery -= 1
      @automove = false
    elsif console_is_key_pressed(KEY_DOWN) || key.c == 'j' 
      @recompute_fov = true if @game.move(hero, :down)
      # $playery += 1
      @automove = false
    elsif console_is_key_pressed(KEY_LEFT) || key.c == 'h' 
      # $playerx -= 1
      @recompute_fov = true if @game.move(hero, :left)
      @automove = false
    elsif console_is_key_pressed(KEY_RIGHT) || key.c == 'l'
      # $playerx += 1
      @recompute_fov = true if @game.move(hero, :right)
      @automove = false
    elsif key.c == 'a'
      @automove = true
    end

    if old_depth != @game.depth
      build_fov_map
    end

    false
  end

  def render
    puts "--- rendering!"

    if @recompute_fov
      puts "--- recomputing FOV..."
      @recompute_fov = false
      map_compute_fov(@fov_map, @game.hero.x, @game.hero.y, @torch_radius, @light_walls, @fov_algorithm)

      0.upto(@height-1) do |y|
	0.upto(@width-1) do |x|
	  visible = map_is_in_fov(@fov_map, x, y)
	  
	  wall = map[x][y].wall? # locked
	  door = map[x][y].door?
	  stair = map[x][y].stair?

	  unless visible
	    if map[x][y].explored?
	      if wall
		console_put_char_ex(@console, x, y, WALL_TILE.ord, Color::WHITE * 0.5, Color::BLACK)
	      elsif door
		console_put_char_ex(@console, x, y, DOOR_TILE.ord, Color::WHITE * 0.5, Color::BLACK)
	      elsif stair
		console_put_char_ex(@console, x, y, UPWARD_STAIR_TILE.ord, Color::WHITE * 0.5, Color::BLACK)
	      else
		console_put_char_ex(@console, x, y, GROUND_TILE.ord, Color::BLACK, GROUND_COLOR * 0.5)
	      end
	    end
	  else
	    # it's visible!
	    if wall
	      console_put_char_ex(@console, x, y, WALL_TILE.ord, Color::WHITE, Color::BLACK)
	    elsif door
	      console_put_char_ex(@console, x, y, DOOR_TILE.ord, Color::WHITE, Color::BLACK)
	    elsif stair
	      console_put_char_ex(@console, x, y, UPWARD_STAIR_TILE.ord, Color::WHITE, Color::BLACK)
	    else
	      console_put_char_ex(@console, x, y, GROUND_TILE.ord, Color::BLACK, GROUND_COLOR)
	    end
	    # explore it...
	    map[x][y].explore!
	  end
	end
      end
    end

    # console_flush()

    #
    puts "--- blitting console..."
    console_blit(@console, 0, 0, @width, @height, nil, 0, 0, 1.0, 1.0)
  end

  def run_forever
    until console_is_window_closed
      render
      console_set_default_foreground(nil, Color::WHITE)
      console_put_char(nil, @game.hero.x, @game.hero.y, '@'.ord, BKGND_NONE)
      console_flush
      console_put_char(nil, @game.hero.x, @game.hero.y, ' '.ord, BKGND_NONE)
      if @automove
	@game.automove 
	key = console_check_for_keypress(1)
	if %[ h j k l ].include?(key.c)
	  @automove = false
	end
      else
	will_exit = handle_keys
      end
      break if will_exit
    end
  end

  class << self
    def play!
      game = RogueConsole.new 
      game.launch!
    end
  end
end

