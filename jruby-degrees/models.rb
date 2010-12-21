require 'rubygems'
require 'neo4j'

Neo4j::Config[:storage_path] = 'movies'

module Finders
  def find_by_name(name)
    (found = find "name: #{name.inspect}") && found.first
  end

  def find_or_create_by_name(name)
    find_by_name(name) || new(:name => name)
  end
end

class Movie; end

class Actor
  include Neo4j::NodeMixin
  extend Finders

  property :name
  index    :name

  has_n(:movies).to(Movie)
end

class Movie
  include Neo4j::NodeMixin
  extend Finders

  property :name
  index    :name

  has_n(:actors).from(Actor, :movies)
end
