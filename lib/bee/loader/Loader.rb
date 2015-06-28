module Bee
  class Loader
    def initialize(fname, config)
      beedb = config.get(:beedb)
      @writer = beedb ?
        Bee.const_get(config.get(:writer)).new(beedb) :
        Bee.const_get(config.get(:writer)).new
      @fname = fname
      @config = config
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

      return (name.downcase.end_with?(*myjunk))
    end

    def load_hook
      raise "ERROR: Load hook is not implemented"
    end
  end
end
