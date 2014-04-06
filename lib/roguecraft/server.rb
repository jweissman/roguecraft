#
# TODO implement multiplay server..
#

require 'libtcod'
require 'sinatra/base'
require 'sinatra-websocket'
require 'json'


require 'eventmachine'
require 'sinatra/base'
require 'thin'

require 'pry'

require 'roguecraft'
require 'roguecraft/server/helpers'
require 'roguecraft/server/api'
require 'roguecraft/server/reactor'

