require 'logger'

module Bee
  class Loader
    include LogUtils

    def initialize(fname, config)
      beedb = config.get(:beedb)
      @writer = beedb ?
        Bee.const_get(config.get(:writer)).new(beedb) :
        Bee.const_get(config.get(:writer)).new
      @fname = fname
      @config = config

      @logger = Logger.new(config.get(:logfile))
      @logger.level = Logger.const_get(config.get(:loglevel))
    end

    def load
      @writer.startup
      load_hook
      @writer.finished

      return true
    end

    def isJunk(name)
      # Skip the uninteresting files!
      myjunk = @config.get(:junkfiles)
      myjunk.size.times do |i|
        myjunk[i].gsub!(/\./, "_")
      end

      skip = name.downcase.end_with?(*myjunk)
      @logger.info("Skipping #{name}") if (skip)

      return (skip)
    end

    def load_hook
      fatalAndRaise("Load hook is not implemented")
    end
  end
end
