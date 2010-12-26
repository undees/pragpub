require 'cgi'
require 'enumerator'
require 'neography'

def shortest_path(from_name, to_name)
  neo  = Neography::Rest.new
  from = neo.get_index 'actor', CGI.escape(from_name)
  to   = neo.get_index 'actor', CGI.escape(to_name)

  return [] unless from && to

  acting = {'type' => 'acting'}
  nodes  = neo.get_path(from.first, to.first, acting, 12)['nodes']

  return [] unless nodes

  nodes.map do |node|
    id = node.split('/').last
    neo.get_node(id)['data']['name']
  end
end
