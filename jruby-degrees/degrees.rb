require 'rubygems'
require 'sinatra'
require 'models'
require 'shortest_path'

get '/' do
  from = params[:from] || 'Kevin Bacon'
  to   = params[:to]   || ''
  list = ''

  unless from.empty? || to.empty?
    path = shortest_path(params[:from], params[:to])

    unless path.empty?
      previous = path.first
      path[1..-1].each_slice(2) do |movie, actor|
        list += %Q(#{previous} was in "#{movie}" with #{actor}<br/>)
        previous = actor
      end
    end
  end

  list + %Q(<form action="/"><input name="from" value="#{from}"/><input name="to" value="#{to}"/><input type="submit"/>)
end
