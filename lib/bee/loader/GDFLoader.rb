module Bee
  class GDFLoader < Loader
    def initialize(fname, writer, config)
      super(fname, writer, config)
      @zone = :no_zone 
      @types = []
    end

    def check_zone(row, zone)
      case row
      when /^\s*nodedef>\s/
        zone = :node_zone
      when /^\s*edgedef>\s/
        zone = :edge_zone
      end

      return zone
    end

    def process_value(type, val)
      # Special handling for time variables (since they are lists)
      case type.intern
      when :totalusertime,:totalsystemtime,:totalelapsedtime,:ownusertime,:ownsystemtime,:ownelapsedtime

        # Strip away square brackets
        val.gsub!(/[\[\]]/, "")
        if (val.empty?)
          val = 0
        else
          val = val.split(";")
          if ([:totalelapsedtime,:ownelapsedtime].include?(type.intern))
            val = val.inject(0.0) {|sum,x|
              mins,secs = x.split(":")
              sum + 60*mins.to_f + secs.to_f
            }
          else
            val = val.map(&:to_f).inject(0.0, :+)
          end
        end
      end

      return val
    end

    def node(row_spl)
      # Skip uninteresting nodes
      return if (isJunk(row_spl[0]))

      @writer.addNode(row_spl[0]) do |n|
        row_spl.size.times do |i|
          @writer.addProperty(n, @types[i].intern, process_value(@types[i], row_spl[i]))
        end

        # Add full filename
        @writer.addProperty(n, :nid,
                            "#{@writer.getProperty(n, :dir)}/#{@writer.getProperty(n, :base)}")

        # Check if it is an internal path
        @writer.addProperty(n, :internal,
                            @writer.getProperty(n, :nid).start_with?("<root>") ? 1 : 0)
      end
    end

    def edge(row_spl)
      # Skip uninteresting nodes
      return if (isJunk(row_spl[0]) or isJunk(row_spl[1]))

      # Find the nodes by name
      from = @writer.getNode(:name, row_spl[0])
      to = @writer.getNode(:name, row_spl[1])

      from_nid = @writer.getProperty(from, :nid)
      to_nid = @writer.getProperty(to, :nid)

      # Get edge type
      if (from_nid.start_with?("<root>") and to_nid.start_with?("<root>"))
        edge_type = :depends
      else
        return # skip external deps for now
        edge_type = :external_depends
      end

      @writer.addEdge(edge_type, from, to) do |e|
         row_spl.size.times do |i|
           @writer.addProperty(e, @types[i].intern, row_spl[i])
         end
      end
    end

    def handle_row(row)
      @zone = check_zone(row, @zone)

      case row
      when /^\s*nodedef>\s/
        @types = row.gsub(/^\s*nodedef>\s/, "").split(",").collect {|x| x.gsub(/\s.*$/, "")}
      when /^\s*edgedef>\s/
        @types = row.gsub(/^\s*edgedef>\s/, "").split(",").collect {|x| x.gsub(/\s.*$/, "")}
      else
        # Check that the split length matches the definition length
        row_spl = row.split(",")
        if (row_spl.size != @types.size)
          raise "ERROR: Row splits have #{row_spl.size} elements while definition specifies #{@types.size}"
        end

        case @zone
        when :node_zone
          node(row_spl)

        when :edge_zone
          edge(row_spl)

        else
          raise "ERROR: Row '#{row}' in an unrecognized zone of the file"
        end
      end
    end

    def load_hook
      File.foreach(@fname) do |row|
        row.strip!
        handle_row(row)
      end
    end
  end
end
