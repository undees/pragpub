require 'java'
require 'cgi'
require 'fileutils'

unless ENV['NEO4J_DIR']
  STDERR.puts 'Please set NEO4J_DIR to the base of your Neo4j install.'
  exit -1
end

Dir["#{ENV['NEO4J_DIR']}/lib/*.jar"].each { |jar| require jar }

java_import org.neo4j.kernel.EmbeddedGraphDatabase
java_import org.neo4j.graphdb.DynamicRelationshipType

class Database
  def neo
    return @neo if @neo

    dir = ENV['NEO4J_DIR'] + '/data/graph.db'
    FileUtils.mkdir_p dir

    @neo = EmbeddedGraphDatabase.new dir
    at_exit { @neo.shutdown }
    @neo
  end

  def transaction
    tx = neo.begin_tx
    begin
      result = yield
      tx.success
      result
    ensure
      tx.finish
      nil
    end
  end

  def Database.acting
    @@acting ||= DynamicRelationshipType.with_name 'acting'
  end

  def find(type, name)
    index = neo.index.for_nodes type
    index.get('name', CGI.escape(name)).get_single
  end

  def create(type, name)
    node = neo.create_node
    node.set_property 'name', name
    index = neo.index.for_nodes type
    index.add node, 'name', CGI.escape(name)
    node
  end

  def find_or_create(type, name)
    find(type, name) || create(type, name)
  end

  def acted_in(actor, movie)
    actor.create_relationship_to movie, Database.acting
  end
end
