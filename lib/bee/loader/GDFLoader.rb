module Bee
  class GDFLoader < Loader

    include LogUtils

    def initialize(config)
      super(config.get(:gdf_file), config)

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
      when :localname,:makefile,:dir,:base
        val=rootify(val,@config.get(:build_home))
      end

      return val
    end

    def node(row_spl)

      # check if node is in use
      is_inuse = row_spl[1].eql?("1")
      
      # Skip uninteresting nodes
      return if (isJunk(row_spl[0]) or !is_inuse)

      @logger.info("Adding node #{row_spl[0]}")
      @writer.addNode(row_spl[0]) do |n|
        row_spl.size.times do |i|
          @writer.addProperty(n, @types[i].intern, process_value(@types[i], row_spl[i]))
        end

        @writer.addLabel(n, :gdf)

        # implicit node check: redundant, so commented out
        #@writer.addProperty(n, :implicit, true)
     
        # Add full filename
        @writer.addProperty(n, :nid, "#{@writer.getProperty(n, :dir)}/#{@writer.getProperty(n, :base)}")

        # Check if it is an internal path
        @writer.addProperty(n, :internal,
                            @writer.getProperty(n, :nid).start_with?("<root>") ? 1 : 0)
      end
    end

    def edge(row_spl)

      # check if edge is implicit
      is_implicit = row_spl[6].eql?("1")

      # Skip uninteresting nodes
      return if (isJunk(row_spl[0]) or isJunk(row_spl[1]) or is_implicit)

      # Find the nodes by name
      from = @writer.getNode(:name, row_spl[0])
      to = @writer.getNode(:name, row_spl[1])

      # Skip edges between nodes that were not in use
      return if (from.nil? or to.nil?)
      
#      from_nid = @writer.getProperty(from, :nid)
#      to_nid = @writer.getProperty(to, :nid)

      # Get edge type
      if (@writer.getProperty(from, :internal) and @writer.getProperty(to, :internal))
        edge_type = :depends
      else
        #return # skip external deps for now
        edge_type = :external_depends
      end

      @logger.info("Adding #{edge_type.to_s} edge from #{row_spl[0]} to #{row_spl[1]}")
      @writer.addEdge(edge_type, from, to) do |e|
         row_spl.size.times do |i|
           @writer.addProperty(e, @types[i].intern, row_spl[i])
         end
      end
      # not_implicit label from nodes if the edge is not implicit: redundant, we remove all implicit edges by default
#      if (!is_implicit)
#        @logger.info("setting implicit property for #{row_spl[0]} and #{row_spl[1]}")
#        @writer.addProperty(from, :implicit, false)
#        @writer.addProperty(to, :implicit, false)
#      end
    end

    def handle_row(row)
      @logger.debug("Processing: #{row}")
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
          fatalAndRaise("Row splits have #{row_spl.size} elements while definition specifies #{@types.size}")
        end

        case @zone
        when :node_zone
          node(row_spl)

        when :edge_zone
          edge(row_spl)

        else
          fatalAndRaise("Row '#{row}' in an unrecognized zone of the file")
        end
      end
    end

    def load_hook
      @logger.info("=== STARTING GDFLoader ===")

      File.foreach(@fname) do |row|
        row.strip!
        handle_row(row)
      end

      @logger.info("== Removing orphans nodes from database")
      remove_orphans
      
      @logger.info("=== FINISHED GDFLoader ===")
    end
  
    def remove_orphans
      Neo4j::Session.query("MATCH (n:gdf) WHERE not( (n)-[]-() ) DELETE n")
    end
  end
end
