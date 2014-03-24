require 'benchmark'
require 'pry'

class RogueConsole
  include Roguecraft
  include TCOD

  DEFAULT_WIDTH  = 50
  DEFAULT_HEIGHT = 37
  DEFAULT_FPS    = 60

  WALL_TILE   = '#'
  GROUND_TILE = ' '
  GOLD_TILE   = '*'

  UPWARD_STAIR_TILE = '<'
  DOWNWARD_STAIR_TILE = '>'
  DOOR_TILE = '+'

  GROUND_COLOR = Color.rgb(77, 77, 77) #60, 41)

  def initialize(opts={})
    @height = opts[:height] || DEFAULT_HEIGHT
    @width  = opts[:width]  || DEFAULT_WIDTH
    @fps    = opts[:fps]    || DEFAULT_FPS

    @torch_radius  = 3
    @light_walls   = true
    @fov_algorithm = 0 # default algo...?
    @recompute_fov = true

    @game = Game.new(width: @width, height: @height, vision_radius: @torch_radius)
  end

  def hero
    @game.hero
  end

  def set_map_properties(x,y)
    map_set_properties(@fov_map, x, y, !@game.block_visible?(x,y), !@game.wall?(x,y))
  end

  def each_position
    0.upto(@height-1) do |y|
      0.upto(@width-1) do |x|
	yield [x,y]
      end
    end
  end

  def write(char,x,y,fore,back)
    console_put_char_ex @console, x, y, char.ord, fore, back
  end

  def build_fov_map
    @fov_map = map_new @width, @height

    each_position do |x,y|
      write(' ', x, y, Color::BLACK, Color::BLACK)
      set_map_properties(x,y)
    end

    console_flush
  end

  def launch!
    console_set_custom_font('arial10x10.png', FONT_TYPE_GREYSCALE | FONT_LAYOUT_TCOD, 0, 0)
    console_init_root(@width, @height, 'roguecraft!', false, RENDERER_SDL)
    sys_set_fps @fps

    @console = console_new(@width, @height) 

    build_fov_map
    run_forever
  end

  def handle_keys
    key = console_wait_for_keypress(true)

    if key.vk == KEY_ENTER && key.lalt
      #Alt+Enter: toggle fullscreen
      console_set_fullscreen(!console_is_fullscreen())
    elsif key.vk == KEY_ESCAPE || key.c == 'q'
      return true  #exit game
    end

    if console_is_key_pressed(KEY_UP) || key.c == 'k' 
      @recompute_fov = true if @game.move(hero, :up)
      @automove = false
    elsif console_is_key_pressed(KEY_DOWN) || key.c == 'j' 
      @recompute_fov = true if @game.move(hero, :down)
      @automove = false
    elsif console_is_key_pressed(KEY_LEFT) || key.c == 'h' 
      @recompute_fov = true if @game.move(hero, :left)
      @automove = false
    elsif console_is_key_pressed(KEY_RIGHT) || key.c == 'l'
      @recompute_fov = true if @game.move(hero, :right)
      @automove = false
    elsif key.c == 'a'
      @automove = true
    end

    false
  end
  
  def tile_and_colors_for(x,y)
    wall       = @game.wall?(x,y)
    door       = @game.door?(x,y)
    up_stair   = @game.up?(x,y)
    down_stair = @game.down?(x,y)

    gold       = @game.gold?(x,y)

    tile_and_colors = if wall
      [WALL_TILE, Color::WHITE, Color::BLACK]
    elsif door
      [DOOR_TILE, Color::RED, Color::BLACK]
    elsif  up_stair
      [UPWARD_STAIR_TILE, Color::WHITE, Color::BLACK]
    elsif down_stair
      [DOWNWARD_STAIR_TILE, Color::WHITE, Color::BLACK]
    elsif gold
      [GOLD_TILE, Color::YELLOW, GROUND_COLOR]
    else
      [GROUND_TILE, Color::BLACK, GROUND_COLOR]
    end

    return tile_and_colors
  end

  def render
    if @recompute_fov
      @recompute_fov = false
      puts "--- computing fov"
      map_compute_fov(@fov_map, hero.x, hero.y, @torch_radius, @light_walls, @fov_algorithm)
      puts "--- writing map...."
      each_position do |x,y|
	visible = map_is_in_fov(@fov_map, x, y)
	character, foreground, background = tile_and_colors_for(x,y)
	if visible
	  @game.explore!(x,y)
	else
	  foreground = foreground * 0.5
	  background = background * 0.5
	end
	write(character, x, y, foreground, background) if @game.explored?(x,y)
      end
    end
    console_print(@console, 0,0, "Gold: #{@game.gold}")
    console_blit(@console, 0, 0, @width, @height, nil, 0, 0, 1.0, 1.0)
  end

  def run_forever
    until console_is_window_closed
      old_depth = @game.current_depth

      render
      console_set_default_foreground(nil, Color::WHITE)
      console_put_char(nil, hero.x, hero.y, '@'.ord, BKGND_NONE)
      console_flush
      console_put_char(nil, hero.x, hero.y, ' '.ord, BKGND_NONE)

      if @automove
	@game.autoexplore 
	@recompute_fov = true
	key = console_check_for_keypress(1)
	if %[ q h j k l ].include?(key.c)
	  @automove = false
	end
      else
	will_exit = handle_keys
      end

      if old_depth != @game.current_depth
	build_fov_map
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

