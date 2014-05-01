require 'libtcod'
require 'minotaur'
require 'logger'

require 'roguecraft/version'
require 'roguecraft/navigation'
require 'roguecraft/entity'
require 'roguecraft/hero'
# require 'roguecraft/dungeon'

require 'roguecraft/game'

module Roguecraft
  class << self
    attr_writer :environment
    def environment
      @environment ||= :production
    end

    attr_accessor :stdout, :logfile
    def setup_loggers
      self.stdout = Logger.new(STDOUT)
      self.logfile = Logger.new("log/#{self.environment}.log")
    end

    def log(msg)
      setup_loggers unless self.stdout && self.logfile
      self.stdout.info(msg) unless self.environment == :test
      self.logfile.info(msg)
    end
  end

  def log(msg)
    Roguecraft.log(msg) 
  end

  def self.logo(small=false)
    log "========================================================="
    if small 
      log "                                            __ _  " 
      log "        _ _ ___  __ _ _  _ ___ __ _ _ __ _ / _| |_" 
      log "       | '_/ _ \\/ _` | || / -_) _| '_/ _` |  _|  _|"
      log "       |_| \\___/\\__, |\\_,_\\___\\__|_| \\__,_|_|  \\__|"
      log "                |___/                             " 
    else
      log "                                                   __ _   " 
      log "                                                  / _| |  " 
      log "        _ __ ___   __ _ _   _  ___  ___ _ __ __ _| |_| |_ " 
      log "       | '__/ _ \\ / _` | | | |/ _ \\/ __| '__/ _` |  _| __|"
      log "       | | | (_) | (_| | |_| |  __/ (__| | | (_| | | | |_ " 
      log "       |_|  \\___/ \\__, |\\__,_|\\___|\\___|_|  \\__,_|_|  \\__|"
      log "                   __/ |                                  " 
      log "                  |___/                                   " 
    end
    log "---------------------------------------------------------"
    log " > Roguecraft v#{Roguecraft::VERSION}"
    log "========================================================="
  end
end


