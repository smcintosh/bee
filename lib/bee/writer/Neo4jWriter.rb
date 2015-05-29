require 'neo4j-core'

module Bee
  class Neo4jWriter < Writer
    def initialize(db_path=".beedb")
      @session = Neo4j::Session.open(:embedded_db, db_path)
      @session.start

      @nodecache = Hash.new
    end

    def startup
      # NOP
    end

    def addNode(name)
      node = nil

      Neo4j::Transaction.run do
        node = Neo4j::Node.create({}, :node)
        yield node
      end

      @nodecache[name] = node.neo_id

      return node
    end

    def addEdge(et, from, to)
      edge = nil

      Neo4j::Transaction.run do
        edge = Neo4j::Relationship.create(et, from, to)
        yield edge
      end

      return edge
    end

    def addProperty(ele, key, val)
      ele[key] = val
    end

    def getProperty(ele, key)
      return ele[key]
    end

    def getNodeByName(name, add=false)
      mynode = Neo4j::Node.load(@nodecache[name])
      if (!mynode) # Cache miss
        mynodes = Neo4j::Label.find_nodes(:node, :name, name)

        if (mynodes.size == 1) # we found it!
          mynode = mynodes[0] 
        elsif (mynodes.size == 0) # Not in graph
          if (add) # Should we try to add the node?
            mynode = addNode(name) do |n|
              addProperty(n, :name, name)
            end
          else
            raise "ERROR: Node '#{name}' not found"
          end
        elsif (mynodes.size > 1)
          raise "ERROR: Unexpected number of nodes #{mynodes.size} with name '#{name}'"
        else
          raise "ERROR: Something very strange happened..."
        end
      end

      return mynode
    end

    def finished
      @session.shutdown
      @session.close
    end
  end
end
