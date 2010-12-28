# START:basics
require 'bundler/setup'
require 'neography'
require 'cgi'

class Database
  def neo
    server = ENV['NEO4J_SERVER'] || 'localhost' # <label id="co.server"/>
    @neo ||= Neography::Rest.new 'http://', server
  end

  def find(type, name)           # <label id="co.find"/>
    hit = neo.get_index type, 'name', CGI.escape(name)
    # get_index will return nil or an array of hashes
    hit && hit.first
  end

  def find_or_create(type, name) # <label id="co.create"/>
    # look for an actor or movie in the index first
    node = find type, name
    return node if node

    node = neo.create_node 'name' => name
    neo.add_to_index type, 'name', CGI.escape(name), node  # <label id="co.index"/>
    node
  end

  def acted_in(actor, movie)
    neo.create_relationship 'acting', actor, movie  # <label id="co.relationship"/>
  end
  # END:basics

  # START:shortest_path
  def shortest_path(from, to)
    from_node = find 'actor', from
    to_node   = find 'actor', to

    return [] unless from_node && to_node

    acting  = {'type' => 'acting'}
    degrees = 6
    depth   = degrees * 2
    nodes   = neo.get_path(from_node, to_node, acting, depth)['nodes'] || []

    nodes.map do |node|
      id = node.split('/').last
      neo.get_node(id)['data']['name']
    end
  end
  # END:shortest_path

  # START:basics
end
# END:basics
