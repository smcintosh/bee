require 'neo4j-core'

module Bee
  class Neo4jWriter < Writer
    def initialize(db_path=".beedb")
      @session = Neo4j::Session.open(:embedded_db, db_path)
      @session.start
    end

    def addNode
      node = nil

      Neo4j::Transaction.run do
        node = Neo4j::Node.create({}, :node)
        yield node
      end

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
      nodes = Neo4j::Label.find_nodes(:node, :name, name)
      if (nodes.count != 1)
        if (add and nodes.count == 0)
          nodes << addNode do |n|
            addProperty(n, :name, name)
          end
        else
          raise "ERROR: Unexpected number of nodes #{nodes.count} with name = '#{name}'" 
        end
      end

      return nodes[0]
    end

    def finished
      @session.shutdown
      @session.close
    end
  end
end
