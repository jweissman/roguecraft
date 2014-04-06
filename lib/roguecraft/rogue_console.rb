# require 'benchmark'
require 'roguecraft/client'

module TCODHelpers
  # only on server now!
  # def set_map_properties(x,y)
  #   map_set_properties(fov_map, x, y, !game.block_visible?(x,y), !game.wall?(x,y))
  # end

  def put_character(char,x,y,fore,back)
    # puts "--- attempting to put char '#{char.ord}' at #{x}, #{y}"
    # binding.pry
    console_put_char_ex console, x, y, char.ord, fore, back # char.ord, fore, back
  end
end

# we could run libtcod on the server, enough to run the fov map, and then pass the generated map back?
# seems a little silly but... maybe simpler?

class RogueConsole
  include Roguecraft
  include Minotaur::Geometry::Directions
  include TCOD
  include TCODHelpers


  DEFAULT_WIDTH  = 80
  DEFAULT_HEIGHT = 57
  DEFAULT_FPS    = 60

  WALL_TILE   = '#'
  GROUND_TILE = ' '
  GOLD_TILE   = '*'
  POTION_TILE = '!'
  SCROLL_TILE = 'o'

  UPWARD_STAIR_TILE = '<'
  DOWNWARD_STAIR_TILE = '>'
  DOOR_TILE = '+'

  GROUND_COLOR = Color.rgb(77, 77, 77) #60, 41)
  # DOOR_COLOR = Color::RED
  # OTHER_HERO_COLOR = Color::BLUE

  def initialize(opts={})
    puts "--- new console created"
    @fps    = opts[:fps]    || DEFAULT_FPS
    @game_client = Roguecraft::Client.new
    @setup_needed = true
  end

  def game
    @game ||= @game_client
  end

  def console
    @console
  end

  # def fov_map
  #   @fov_map
  # end

  def handle_keys
    key = console_check_for_keypress(1)
    if key.vk == KEY_ESCAPE || key.c == 'q'
      puts "--- ESCAPE"
      return true  
    end

    if console_is_key_pressed(KEY_UP) || key.c == 'k' 
      game.move!(NORTH)
    elsif console_is_key_pressed(KEY_DOWN) || key.c == 'j' 
      game.move!(SOUTH)
    elsif console_is_key_pressed(KEY_LEFT) || key.c == 'h' 
      game.move!(WEST)
    elsif console_is_key_pressed(KEY_RIGHT) || key.c == 'l'
      game.move!(EAST)
    elsif key.c == 'a'
      game.autopilot!
    end

    if %[ q h j k l ].include?(key.c)
      game.autopilot!(false)
    end

    false
  end

  def tile_and_colors_for(x,y)
    wall       = game.wall?(x,y)
    door       = game.door?(x,y)
    up_stair   = game.up?(x,y)
    down_stair = game.down?(x,y)
    gold       = game.gold?(x,y)
    potion     = game.potion?(x,y)
    scroll     = game.scroll?(x,y)


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
		      elsif potion
			[POTION_TILE, Color::WHITE, GROUND_COLOR]
		      elsif scroll
			[SCROLL_TILE, Color::WHITE, GROUND_COLOR]
		      else
			[GROUND_TILE, Color::BLACK, GROUND_COLOR]
		      end

    return tile_and_colors
  end

  def reflow!
    # need to request tiles again?

    console_clear(@console)
  end

  # ugh this takes so long
  def recompute
    # puts "--- recomputing!"
    # t0 = Time.now
    # same_level_heroes = game.heroes.select { |h| h.depth == game.hero.depth }
    # all_explored = same_level_heroes.map { |h| h.explored || [] }.reduce(&:+).uniq

    game.each_position do |x,y|
      if game.explored?(x,y) # hero.explored.include?([x,y])
	visible = game.hero.visible.include?([x,y])
	character, foreground, background = tile_and_colors_for(x,y)

	unless visible
	  foreground = foreground * 0.5
	  background = background * 0.5
	end

	put_character(character, x, y, foreground, background) 
      end
    end

    # puts "=== recompute took #{Time.now - t0} ms"
    @should_recompute = false
  end

  def should_recompute?
    @should_recompute
  end

  def recompute!
    @should_recompute = true
  end

  def render
    console_print(@console, 0,0, "Gold: #{game.hero.gold}")
    console_print(@console, 0,1, "Depth: #{game.hero.depth}")
    console_blit(@console, 0, 0, game.width, game.height, nil, 0, 0, 1.0, 1.0)

    (game.heroes - [game.hero]).each do |other_hero|
      if other_hero.depth == game.depth
	console_set_default_foreground(nil, Color::BLUE)
	console_put_char(nil, other_hero.x, other_hero.y, '@'.ord, BKGND_NONE)
      end
    end

    console_set_default_foreground(nil, Color::WHITE)
    console_put_char(nil, game.hero.x, game.hero.y, '@'.ord, BKGND_NONE)
    console_flush
  end


  def update
    recompute if should_recompute?
    handle_keys || console_is_window_closed
  end

  def setup_console
    puts "--- setup"
    console_set_custom_font('arial10x10.png', FONT_TYPE_GREYSCALE | FONT_LAYOUT_TCOD, 0, 0)
    console_init_root(game.width, game.height, 'roguecraft!', false, RENDERER_SDL)
    sys_set_fps @fps

    @console = console_new(game.width, game.height) 

    @should_recompute = true
    @setup_needed = false
  end

  def game_loop
    # puts "tick!"
    # @last_tick ||= 0
    # puts "---- tick (last was at #{Time.now - @last_tick} ago)"
    # @last_tick = Time.now

    setup_console if @setup_needed

    #Benchmark.bm do |x|
    should_exit = update
    render
    should_exit
    # end
  end

  # def report(phase_name)
  #   #t0 = Time.now
  #   #yield
  #   #puts "#{phase_name}: #{Time.now-t0}"
  # end

  def run_forever
    game.react(self) { game_loop }
  end

  def launch!
    # build_fov_map
    run_forever
  end

  class << self
    def play!
      game = RogueConsole.new 
      game.launch!
    end
  end
end

