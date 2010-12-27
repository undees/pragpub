require 'enumerator'
require 'sinatra'
require 'haml'
require 'lib/database'

get '/' do
  from = params[:from] || 'Kevin Bacon'
  to   = params[:to]   || ''

  path = if to.empty?
           []
         else
           Database.new.shortest_path from, to
         end

  previous = path.shift
  @results = path.each_slice(2).map do |slice| #<label id="co.slice"/>
    movie, actor = slice
    result = %Q(#{previous} was in "#{movie}" with #{actor})
    previous = actor
    result
  end

  @from = CGI.escapeHTML from
  @to   = CGI.escapeHTML to

  haml :index
end
