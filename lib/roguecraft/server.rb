#
# TODO implement multiplay server..
#
require 'roguecraft'

require 'sinatra/base'
require 'sinatra-websocket'
require 'json'

require 'eventmachine'
require 'sinatra/base'
require 'thin'


module Roguecraft
  # Our simple hello-world app
  class API < Sinatra::Base
    # threaded - False: Will take requests on the reactor thread
    #            True:  Will queue request for background thread
    configure do
      set :threaded, false
      set :sockets, []
    end

    # Request runs on the reactor thread (with threaded set to false)
    get '/hello' do
      'Hello World'
    end

    # Request runs on the reactor thread (with threaded set to false)
    # and returns immediately. The deferred task does not delay the
    # response from the web-service.
    get '/delayed-hello' do
      EM.defer do
	sleep 5
      end
      'I\'m doing work in the background, but I am still free to take requests'
    end

    get '/map.json' do
      @game = $game
      {
	version: 1,
	height: @game.height,
	width:  @game.width,
	orientation: 'orthogonal',
	properties: {},
	layers: [{
	  data:   @game.map.flatten.map { |i| i+1 },
	  height: @game.height,
	  width:  @game.width,
	  name: 'ground',
	  opacity: 1,
	  type: 'tilelayer',
	  visible: true,
	  x: 0,
	  y: 0
        }],

	tileheight: 32,
	tilewidth: 32, 

	tilesets: [
	  {
	    firstgid: 1,
	    image: 'assets/images/wood.png',
	    imageheight: 31,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: 'wood',
	    properties: {},
	    tileheight: 32,
	    tilewidth: 32
          },    
	  {
	    firstgid: 2,
	    image: 'assets/images/stone.png',
	    imageheight: 32,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: 'stone',
	    properties: {},
	    tileheight: 32,
	    tilewidth: 32
	  },    
	  {
	    firstgid: 3,
	    image: 'assets/images/door.png',
	    imageheight: 32,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: 'door',
	    properties: {},
	    tileheight: 32,
	    tilewidth: 32
	  },    
	  {
	    firstgid: 4,
	    image: 'assets/images/up.png',
	    imageheight: 32,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: 'upstairs',
	    properties: {},
	    tileheight: 32,
	    tilewidth: 32
	  },    
	  {
	    firstgid: 5,
	    image: 'assets/images/down.png',
	    imageheight: 32,
	    imagewidth: 32,
	    margin: 0,
	    spacing: 0,
	    name: 'downstairs',
	    properties: {},
	    tileheight: 32,
	    tilewidth: 32
         }
	]
      }.to_json
    end

    get '/' do
      if !request.websocket?
	erb :index
      else
	request.websocket do |ws|
	  ws.onopen do
	    ws.send("Hello World!")
	    settings.sockets << ws
	  end
	  ws.onmessage do |msg|
	    EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
	  end
	  ws.onclose do
	    warn("websocket closed")
	    settings.sockets.delete(ws)
	  end
	end
      end
    end
  end
end

def run(opts)

  # Start the reactor
  EM.run do

    # define some defaults for our app
    server  = opts[:server] || 'thin'
    host    = opts[:host]   || '0.0.0.0'
    port    = opts[:port]   || '8181'
    web_app = opts[:app]

    # create a base-mapping that our application will set at. If I
    # have the following routes:
    #
    #   get '/hello' do
    #     'hello!'
    #   end
    #
    #   get '/goodbye' do
    #     'see ya later!'
    #   end
    #
    # Then I will get the following:
    #
    #   mapping: '/'
    #   routes:
    #     /hello
    #     /goodbye
    #
    #   mapping: '/api'
    #   routes:
    #     /api/hello
    #     /api/goodbye
    dispatch = Rack::Builder.app do
      map '/' do
	run web_app
      end
    end

    # NOTE that we have to use an EM-compatible web-server. There
    # might be more, but these are some that are currently available.
    unless ['thin', 'hatetepe', 'goliath'].include? server
      raise "Need an EM webserver, but #{server} isn't"
    end

    # Start the web server. Note that you are free to run other tasks
    # within your EM instance.
    Rack::Server.start({
      app:    dispatch,
      server: server,
      Host:   host,
      Port:   port
    })


    puts "--- starting roguecraft game on server!"
    $game = Roguecraft::Game.new
    puts "--- done!"

    Signal.trap("INT")  { EventMachine.stop }
    Signal.trap("TERM") { EventMachine.stop }
  end
end

# start the application
# server = Roguecraft::Server.new
run app: Roguecraft::API.new

