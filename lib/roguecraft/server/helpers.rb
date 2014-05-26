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

    def tileset
      @tileset ||= { :empty => 0, :wood => 1, :stone => 2, :door => 3, :up => 4, :down => 5, :gold => 6, :potion => 7, :scroll => 8 }
    end

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
      entities = game.entities[level]
      if entities
	#game.entities[level]
	entities.map do |e| #(&:to_h)
	  { type: e.type, amount: e.amount, x: e.location.x, y: e.location.y } # color...? #, depth: e.current_depth }
	end
      else
	[]
      end
    end


    def generate_tiles(game, level)
      # puts "=== GENERATE TILES FOR LEVEL #{level}"
      level = level.to_i if level.is_a?(String)
      @tiles ||= {}
      @tiles[level] ||= game.map_for_level(level).map { |r| r.map { |i| i+1 }}
    end

    def generate_entity_tiles(game, level) 
      level = level.to_i if level.is_a?(String)
      entity_tiles ||= []

      game.map_for_level(level).each_with_index do |row,y|
	entity_tiles[y] = []
	row.each_with_index do |_,x|
	  entity = game.entity_at(level, x, y)
	  entity_tiles[y][x] = tileset[entity.nil? ? :empty : :gold]
	end
      end

      entity_tiles
    end

    def generate_object_list(level)
      @object_list ||= []
      @object_list[level] ||= game.entities[level].sort_by { |e| e.type }.map do |entity|	
	{
	  name: entity.type,
	  properties: { entity_id: entity.guid, depth: level },

	  type:       entity.type,
	  gid:        tileset[entity.type],
	  # entity_id:       entity.guid,
	  visible:    false,
	  width:      32,
	  height:     32,
	  x:          entity.location.x * 32,
	  y:          entity.location.y * 32,
	  z:          0
	}
      end

      # puts "=== returning object list for level #{level}"
      # puts JSON.pretty_generate(@object_list[level]) #.to_json

      @object_list[level]
    end

    def generate_phaser_tilemap(level)
      @tilemaps ||= {}
      @entity_groups ||= []
      @entity_groups[level] ||= nil 
      if game.entities[level]
        @entity_groups[level] = {
	  objects: generate_object_list(level),
	  height: game.height,
	  width: game.width,
	  name: 'entities',
	  opacity: 1,
	  type: 'objectgroup',
	  visible: true,
	  x: 0,
	  y: 0
        }
      end

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
        }, @entity_groups[level]].flatten,

	tileheight: 32,
	tilewidth: 32, 
	tilesets: tileset.map do |name, gid|
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
