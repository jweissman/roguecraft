module Roguecraft
  module HeroesHelper
    # def hero_attributes(game, hero)
    #   # binding.pry unless hero.depth
    #   puts "--- creating hero attrs"
    #   attrs = { # hero_id: game.heroes.index(hero), 
    #     x: hero.x, y: hero.y, 
    #     depth: hero.depth, 
    #     name: hero.name, 
    #     gold: hero.gold,
    #     id: hero.uuid,
    #     explored: hero.explored, #[hero.depth],
    #     visible: hero.visible, # game.visible_cells(hero)
    #   }
    #   # puts "--- assembling attributes: #{attrs.inspect}"
    #   attrs
    # end
  end


  module TilesHelper

    # def generate_hero_list(game)
    #   game.heroes.map do |hero|
    #     hero_attributes(game, hero)	
    #     # { hero_id: id, x: hero.x, y: hero.y, depth: hero.depth, name: hero.name }
    #   end
    # end
    #
    def generate_entities(game, level)
      # puts "--- #{game.entities}"
      level = level.to_i if level.is_a?(String)
      
      game.entities[level].map do |e| #(&:to_h)
	{ type: e.type, amount: e.amount, x: e.location.x, y: e.location.y } # color...? #, depth: e.current_depth }
      end
    end


    def generate_tiles(game, level)
      # puts "=== GENERATE TILES FOR LEVEL #{level}"
      level = level.to_i if level.is_a?(String)
      @tiles ||= {}
      @tiles[level] ||= game.map_for_level(level).map { |r| r.map { |i| i+1 }}
    end

    def generate_phaser_tilemap(level)
      tilesets = { :wood => 1, :stone => 2, :door => 3, :up => 4, :down => 5 }
      @tilemaps ||= {}
      @tilemaps[level] ||= {
        version: 1,
        height: game.height,
        width:  game.width,
        orientation: 'orthogonal',
        properties: {},
        layers: [{
          data: generate_tiles(game,level).flatten,
          height: game.height,
          width:  game.width,
          name: 'ground',
          opacity: 1,
          type: 'tilelayer',
          visible: true,
          x: 0,
          y: 0
        }],

	tileheight: 32,
	tilewidth: 32, 
	tilesets: tilesets.map do |name, gid|
	  {
	    firstgid: gid,
	    image: "assets/images/#{name}.png",
	    imageheight: 32,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: name,
	    properties: {},
	    tilewidth: 32,
	    tileheight: 32
	  }
	end
      }

      puts "=== returning tilemap for level #{level}"
      @tilemaps[level] #.to_json
    # rescue
    #   binding.pry
    end
  end
end
