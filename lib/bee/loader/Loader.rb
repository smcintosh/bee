module Bee
  class Loader
    def initialize(fname, writer, config)
      @writer = writer
      @fname = fname
      @config = config
    end

    def load
      load_hook

      @writer.finished

      return true
    end

    def isJunk(name)
      # Skip the uninteresting files!
      # For some reason, splat operator doesn't seem to work for class
      # variables, so we store it as a local variable, and then splat it
      myjunk = @config.junkfiles
      return (name.downcase.end_with?(*myjunk))
    end

    def load_hook
      raise "ERROR: Load hook is not implemented"
    end

    def handle_row(row_spl)
      raise "ERROR: Row handler is not implemented"
    end

  end
end
