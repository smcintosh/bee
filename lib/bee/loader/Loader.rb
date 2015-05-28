module Bee
  class Loader
    def initialize(fname, writer)
      @rownum = 0
      @writer = writer
      @fname = fname
    end

    def handle_row(row_spl)
      raise "ERROR: Row handler is not implemented"
    end

    def load
      File.foreach(@fname) do |row|
        row.strip!
        handle_row(row)
      end
    end
  end
end


