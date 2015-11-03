require 'neo4j-core'

module Bee
  class Node
    def initialize(name, label)
      @name = name
      @label = label
      @id = -1
      @command = ""
      @dir = ""
      @taskid = -1
      @fname = ""
      @internal = 0
      @pkg = ""
    end

    def name
      @name
    end

    def label
      @label
    end

    def id
      @id
    end

    def id=(id)
      @id = id
    end

    def command
      @command
    end

    def command=(c)
      @command = c
    end

    def internal
      @internal
    end

    def internal=(i)
      @internal = i
    end

    def dir
      @dir
    end

    def dir=(d)
      @dir = d
    end

    def taskid
      @taskid
    end

    def taskid=(id)
      @taskid = id
    end

    def fname
      @fname
    end

    def fname=(fname)
      @fname = fname
    end

    def pkg
      @pkg
    end

    def pkg=(pkg)
      @pkg = pkg
    end

    def to_s
      "Name: #{@name}, id: #{@id}, taskid: #{@taskid}, command: #{@command}, dir: #{@dir}"
    end


  end

  class CsvWriter < Writer
    def initialize(db_path=".beedb")
      #@session = Neo4j::Session.open(:embedded_db, db_path)
      #@session.start

      @node_id = 0
      @nodecache = Hash.new
      @filecache = Hash.new
    end

    def startup
      # NOP
    end

    # load the GDF nodes so we can reuse them for relations
    def loadNodes()
      puts "Loading nodes"
      headersSkipped = false
      @nodescsv = File.open("gdf_nodes.csv", 'r')
      @nodescsv.each_line { |l|
        l = l.split("\t")
        if (headersSkipped)
          id = l[0].to_i
          n = Node.new(l[2], l[1])
          n.id = id
          n.dir = l[3]
          n.command = l[4]
          n.fname = l[5].sub! "\n", ""
          if (!n.fname.eql?(""))
            @filecache[n.fname] = n
          end
          @nodecache[l[2]] = n
        end
        headersSkipped = true

      }
      @node_id = @nodecache.length
      puts "Done! (#{@node_id} nodes imported)"
    end


    def setHeaders(type)
      case type
      when "gdf"
        @nodescsv = File.open("gdf_nodes.csv", 'w')
        @edgescsv = File.open("gdf_edges.csv", 'w')
        @edgescsv.puts("start\tend\ttype:string:relations")
        @nodescsv.puts("nid:int:nids\tfrom:label\tname:string:targets\tdir\tcommand\tfname")
      when "strace"
        @nodescsv = File.open("gdf_nodes.csv", 'a')
        @edgescsv = File.open("gdf_edges.csv", 'a')
      else
        @logger.error("Unknown type, exiting")
      end
    end

    def addNode(name, from, dir="", command="", fname="", pkg="")
      node = Node.new(name, from)
      @nodecache[node.name] = node
      node.id = @node_id
      node.dir = dir
      node.command = command
      node.fname = fname

      @nodescsv.puts("#{node.id}\t#{node.label}\t#{node.name}\t#{node.dir}\t#{node.command}\t#{node.fname}")

      @node_id = @node_id + 1

      if (!fname.eql?("") && !@filecache.has_key?(fname))
        @filecache[fname] = node
      end
      return node
    end

    def getNode(name)
      return @nodecache[name]
    end

    def getFileNode(fname)
      if (@filecache.has_key?(fname))
        return @filecache[fname]
      elsif(@nodecache.has_key?(fname))
        return @nodecache[fname]
      else
        return nil
      end
    end

    def addEdge(from, to, type)
      @edgescsv.puts("#{@nodecache[from].id}\t#{@nodecache[to].id}\t#{type}")
    end

    def addProperty(ele, key, val, label=false)
      nil
    end

    def addLabel(ele, label)
      nil
    end

    def getProperty(ele, key)
      nil
    end

    def finished
      #@session.shutdown
      #@session.close
      @nodescsv.close()
      @edgescsv.close()
    end
  end
end
