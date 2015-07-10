require 'neo4j-core'

module Bee
   class Neo4jAggregator
     include LogUtils

     def initialize(config)
       db_path = config.get(:beedb)
       @session = Neo4j::Session.open(:embedded_db, db_path)
       @session.start
       @dependencies = Hash.new
       @logger = Logger.new(config.get(:outputfile))
       @ignore_patterns = config.get(:ignore_patterns)
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
       # notice: results of this query represent a bug if there is no dependency n2->n1  !!
       return Neo4j::Session.query("MATCH (node1:gdf)-[:read]->(compiler:strace)-[:write|read*0..10]->(node3)-[:write]->(node2:gdf) return node1, node2,compiler")
     end


     def matches_ignored_pattern(n1, n2)
       # check if n1 and n2 match a configured ignore pattern
       # these patterns e.g. represent side effects of a compiler
       # get extensions
       n1_ext = n1.rpartition("_").last
       n2_ext = n2.rpartition("_").last
       pattern = "#{n1_ext}->#{n2_ext}"
       @ignore_patterns.each do |p|
         if p.eql?(pattern)
           return true
         end
       end
       return false
     end


     def find_rw_dependency_bugs()
       puts "Finding r/w/dependency bugs..."
       # find all dependencies
       get_dependencies()
       # find all rw nodes
       rw_nodes = get_rw_nodes()
       cnt = 0
       # filter nodes in dependencies from rw_nodes
       rw_nodes.each do |n|
         n1 = n.node1[:name]
         n2 = n.node2[:name]
         if (!n1.eql?(n2) && (!@dependencies.has_key?(n2) || !@dependencies[n2].has_key?(n1)))
           # check if we want to ignore this pattern
           if(!matches_ignored_pattern(n1,n2))
             @logger.info("Possible issue found: #{n1}-R->#{n.compiler[:dir]}/#{n.compiler[:command]}->#{n2}")
           end
         end
         cnt = cnt + 1
       end
       puts "DONE (total rw_nodes analyzed: #{cnt})"
     end
   end
end