require 'models'
require 'java'
require 'enumerator'
require 'neo4j-graph-algo-0.7-1.2.M04.jar'

java_import 'org.neo4j.graphalgo.GraphAlgoFactory'
java_import 'org.neo4j.kernel.Traversal'
java_import 'org.neo4j.graphdb.DynamicRelationshipType'

def shortest_path(from_name, to_name)
  from = Actor.find_by_name from_name
  to   = Actor.find_by_name to_name

  return [] unless from && to

  finder = GraphAlgoFactory.shortestPath \
    Traversal.expanderForAllTypes, 12

  path = finder.find_single_path \
    from._java_node,
    to._java_node

  return [] unless path

  path.select { |n| n.has_property :name }.map { |n| n[:name] }
end
