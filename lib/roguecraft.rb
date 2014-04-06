require 'libtcod'
require 'minotaur'

require 'roguecraft/version'
require 'roguecraft/navigation'
require 'roguecraft/entity'
require 'roguecraft/hero'
# require 'roguecraft/dungeon'

require 'roguecraft/game'

module Roguecraft
  def self.logo(small=false)
    puts "========================================================="
    if small 
      puts "                                            __ _  " 
      puts "        _ _ ___  __ _ _  _ ___ __ _ _ __ _ / _| |_" 
      puts "       | '_/ _ \\/ _` | || / -_) _| '_/ _` |  _|  _|"
      puts "       |_| \\___/\\__, |\\_,_\\___\\__|_| \\__,_|_|  \\__|"
      puts "                |___/                             " 
    else
      puts "                                                   __ _   " 
      puts "                                                  / _| |  " 
      puts "        _ __ ___   __ _ _   _  ___  ___ _ __ __ _| |_| |_ " 
      puts "       | '__/ _ \\ / _` | | | |/ _ \\/ __| '__/ _` |  _| __|"
      puts "       | | | (_) | (_| | |_| |  __/ (__| | | (_| | | | |_ " 
      puts "       |_|  \\___/ \\__, |\\__,_|\\___|\\___|_|  \\__,_|_|  \\__|"
      puts "                   __/ |                                  " 
      puts "                  |___/                                   " 
    end
    puts "---------------------------------------------------------"
    puts " > Roguecraft v#{Roguecraft::VERSION}"
    puts "========================================================="
  end
end


