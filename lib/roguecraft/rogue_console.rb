# require 'benchmark'
require 'roguecraft/client'

module TCODHelpers
  def set_map_properties(x,y)
    map_set_properties(fov_map, x, y, !game.block_visible?(x,y), !game.wall?(x,y))
  end

  def put_character(char,x,y,fore,back)
    # puts "--- attempting to put char '#{char.ord}' at #{x}, #{y}"
    # binding.pry
    console_put_char_ex console, x, y, char.ord, fore, back # char.ord, fore, back
  end
end

class RogueConsole
  include Roguecraft
  include Minotaur::Geometry::Directions
  include TCOD
  include TCODHelpers


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
  # DOOR_COLOR = Color::RED
  # OTHER_HERO_COLOR = Color::BLUE

  def initialize(opts={})
    puts "--- new console created"
    # @height = opts[:height] || DEFAULT_HEIGHT
    # @width  = opts[:width]  || DEFAULT_WIDTH
    @fps    = opts[:fps]    || DEFAULT_FPS

    @torch_radius  = 3
    @light_walls   = true
    @fov_algorithm = 0 # default algo...?
    @recompute_fov = true

    # @game_client = Client.new('localhost:8181')	
    @game_client = Roguecraft::Client.new
    # @game = Game.new(width: @width, height: @height, vision_radius: @torch_radius)

    # @hero_id = game.add_hero
    # @tiles = OpenStruct.new(game.tiles(hero)) #data
    @setup_needed = true
  end

  # def hero
  #   @hero ||= OpenStruct.new(game.hero)
  # end

  def game
    @game ||= @game_client
  end

  def console
    @console
  end

  def fov_map
    @fov_map
  end

  # def hero
  #   game.hero #es[@hero_id]
  # end

  ###



  def build_fov_map
    @fov_map = map_new game.width, game.height

    game.each_position do |x,y|
      put_character(' ', x, y, Color::BLACK, Color::BLACK)
      set_map_properties(x,y)
    end

    console_flush
  end


  def handle_keys
    # puts "--- checking for keys"
    # key = console_wait_for_keypress(true)
    key = console_check_for_keypress(1)
    # if key.vk == KEY_ENTER && key.lalt
    #   #Alt+Enter: toggle fullscreen
    #   console_set_fullscreen(!console_is_fullscreen())
    # els

    if key.vk == KEY_ESCAPE || key.c == 'q'
      puts "--- ESCAPE"
      return true  #exit game
    end

    if console_is_key_pressed(KEY_UP) || key.c == 'k' 
      @recompute_fov = true if game.move!(NORTH)
      @automove = false
    elsif console_is_key_pressed(KEY_DOWN) || key.c == 'j' 
      @recompute_fov = true if game.move!(SOUTH) # :down)
      @automove = false
    elsif console_is_key_pressed(KEY_LEFT) || key.c == 'h' 
      @recompute_fov = true if game.move!(WEST) # :left)
      @automove = false
    elsif console_is_key_pressed(KEY_RIGHT) || key.c == 'l'
      @recompute_fov = true if game.move!(EAST) # :right)
      @automove = false
    elsif key.c == 'a'
      @automove = true
    end

    false
  end

  def tile_and_colors_for(x,y)
    wall       = game.wall?(x,y)
    door       = game.door?(x,y)
    up_stair   = game.up?(x,y)
    down_stair = game.down?(x,y)

    gold       = game.gold?(x,y)

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
    # puts "--- render!"
    if @recompute_fov
      explored = []
      @recompute_fov = false
      build_fov_map
      puts "--- computing fov"
      map_compute_fov(@fov_map, game.hero.x, game.hero.y, @torch_radius, @light_walls, @fov_algorithm)
      puts "--- writing map...."
      game.each_position do |x,y|
	visible = map_is_in_fov(@fov_map, x, y)
	character, foreground, background = tile_and_colors_for(x,y)
	if visible
	  # puts ">>> WOULD BE EXPLORING..."
	  explored << [x,y]
	  # game.hero.explore!(x,y)
	else
	  foreground = foreground * 0.5
	  background = background * 0.5
	end
	# binding.pry
	put_character(character, x, y, foreground, background) # if game.hero.explored[y][x] #?(x,y)
      end

      puts "--- explore!"
      game.explore!(explored)
    end

    console_print(@console, 0,0, "Gold: #{game.hero.gold}")
    console_blit(@console, 0, 0, game.width, game.height, nil, 0, 0, 1.0, 1.0)

    # hmm
    (game.heroes - [game.hero]).each do |other_hero|
      console_set_default_foreground(nil, Color::BLUE)
      console_put_char(nil, other_hero.x, other_hero.y, '@'.ord, BKGND_NONE)
      #console_flush
      # console_put_char(nil, other_hero.x, other_hero.y, ' '.ord, BKGND_NONE)
    end

    console_set_default_foreground(nil, Color::WHITE)
    console_put_char(nil, game.hero.x, game.hero.y, '@'.ord, BKGND_NONE)
    console_flush
    # console_put_char(nil, game.hero.x, game.hero.y, ' '.ord, BKGND_NONE)


  end


  def update
    # puts "--- update"
    # binding.pry
    old_depth = game.depth # @game.current_depth
    if @automove
      # send autoexplore command to server...
      game.hero.autoexplore 
      @recompute_fov = true
      key = console_check_for_keypress(1)
      if %[ q h j k l ].include?(key.c)
	@automove = false
      end
    else
      will_exit = handle_keys
    end

    if old_depth != game.depth
      # build_fov_map
      @recompute_fov = true
    end

    will_exit || console_is_window_closed
  end

  def setup_console
    puts "--- setup"
    console_set_custom_font('arial10x10.png', FONT_TYPE_GREYSCALE | FONT_LAYOUT_TCOD, 0, 0)
    console_init_root(game.width, game.height, 'roguecraft!', false, RENDERER_SDL)
    sys_set_fps @fps

    @console = console_new(game.width, game.height) 
    @setup_needed = false
    puts "--- setup done! setup? #{@setup_needed}"
  end


  # def setup_needed?; @setup_needed ||= true end

  def game_loop
    # puts "--- loop! setup? #{@setup_needed}"
    setup_console if @setup_needed # (@setup_needed||=true)
    # puts "--- loop after setup! setup? #{@setup_needed}"
    # until console_is_window_closed
    render
    update
  end

  def run_forever
    game.react { game_loop }
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

