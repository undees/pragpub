require 'enumerator'
require 'rubygems'
require 'sinatra'
require 'lib/shortest_path'

get '/' do
  from = params[:from] || 'Kevin Bacon'
  to   = params[:to]   || ''
  list = ''

  unless from.empty? || to.empty?
    path = shortest_path(params[:from], params[:to])

    unless path.empty?
      previous = path.shift
      path.each_slice(2) do |slice|
        movie, actor = slice
        list += %Q(#{previous} was in "#{movie}" with #{actor}<br/>)
        previous = actor
      end
    end
  end

  from.gsub! '"', '&quot;'
  to.gsub!   '"', '&quot;'

  list + %Q(<form action="/"><input name="from" value="#{from}"/><input name="to" value="#{to}"/><input type="submit"/>)
end
