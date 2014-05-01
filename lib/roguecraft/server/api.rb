class Roguecraft::API < Sinatra::Base
  include Minotaur::Support::DirectionHelpers
  include Minotaur::Geometry
  include Minotaur::Geometry::Directions
  include Roguecraft::HeroesHelper
  include Roguecraft::TilesHelper

  configure do
    set :threaded, true
    set :game, Roguecraft::Game.new
  end

  get '/heroes.json' do
    settings.game.heroes.map do |hero|
      hero.attributes
      # hero_attributes(settings.game, hero)
    end.to_json
  end

  get '/:level/entities.json' do
    generate_entities(settings.game, level).to_json
  end

  get '/:level/tiles.json' do
    puts "=== GET /[level]/tiles.json"
    # puts "--- #{params.inspect}"
    {data: generate_tiles(settings.game, level), width: settings.game.width, height: settings.game.height}.to_json
  end

  get '/:level/tilemap.json' do
    puts "=== GET /[level]/tiles.json"
    puts "--- level => #{level}"
    #hero = ######settings.game.find_hero(params[:hero_id])
    generate_phaser_tilemap(level).to_json
  end

  def game
    settings.game
  end

  def level
    (params[:level] || 0).to_i
  end

  get '/' do
    if !request.websocket?
      erb :index
    else
      request.websocket do |ws|
	game.handle_request(ws)
      end
    end
  end
end
