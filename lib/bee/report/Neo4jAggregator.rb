require 'neo4j-core'

module Bee
   class Neo4jAggregator
     include LogUtils

     def initialize(config, db_path=".beedb")
       @session = Neo4j::Session.open(:embedded_db, db_path)
       @session.start
       @dependencies = Hash.new
       @logger = Logger.new(config.get(:outputfile))
     end
     
     def get_dependencies()
       data = Neo4j::Session.query("MATCH (node1:gdf)-[:depends*]->(node2:gdf) return node1,node2")
       data.each do |d|
        n1 = d.node1[:name]
        n2 = d.node2[:name]
        if (!@dependencies.has_key?(n1))
          @dependencies[n1] = Hash.new
        end
        @dependencies[n1][n2] = true
       end
       
     end
     
     def get_rw_nodes()
       return Neo4j::Session.query("MATCH (node1:gdf)-[:read]->(compiler:strace)-[:write|read*1..10]->(node2:gdf) return node1, node2,compiler")
     end
     
     def find_rw_dependency_bugs()
       # find all dependencies
       get_dependencies()

       # find all rw nodes
       rw_nodes = get_rw_nodes()
       
       # filter nodes in dependencies from rw_nodes
       rw_nodes.each do |n|
         n1 = n.node1[:name]
         n2 = n.node2[:name]               
         if (!@dependencies.has_key?(n1) || !@dependencies[n1].has_key?(n2))
           @logger.info("Possible issue found: #{n.node1[:name]} - #{n.node2[:name]} - #{n.compiler[:dir]}/#{n.compiler[:command]}")
         end
       end
     end
   end
end