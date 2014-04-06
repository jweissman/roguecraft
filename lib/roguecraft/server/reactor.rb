include Roguecraft::HeroesHelper
include Roguecraft::TilesHelper

def run(opts)

  # Start the reactor
  EM.run do
    # define some defaults for our app
    server  = opts[:server] || 'thin'
    host    = opts[:host]   || '0.0.0.0'
    port    = opts[:port]   || '8181'
    web_app = opts[:app]

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

    # web_app.step!
    game = web_app.settings.game
    # sockets = web_app.settings.sockets

    game.react! #(sockets)
    # puts "--- starting roguecraft game on server!"
    #$game = Roguecraft::Game.new
    # puts "--- done!"

    Signal.trap("INT")  { EventMachine.stop }
    Signal.trap("TERM") { EventMachine.stop }
  end
end

# start the application
# = Roguecraft::API.new
run app: Roguecraft::API.new

