require 'rubygems'
require 'neo4j'

Neo4j::Config[:storage_path] = 'movies'

class Movie < Neo4j::Model; end

class Actor < Neo4j::Model
  property :name
  index :name
  has_n(:movies).to(Movie)
end

class Movie < Neo4j::Model
  property :name
  index :name
  has_n(:actors).from(Actor, :movies)
end
