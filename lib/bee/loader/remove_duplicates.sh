# remove duplicate nodes and edges
#head -1 gdf_nodes.csv > nodes_uniq.csv
#tail -n+2 gdf_nodes.csv | sort | uniq -u >> nodes_uniq.csv 
head -1 gdf_edges.csv > edges_uniq.csv
tail -n+2 gdf_edges.csv | sort | uniq -u >> edges_uniq.csv 

