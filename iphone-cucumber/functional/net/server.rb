require 'rubygems'
require 'sinatra'

post '/path' do
  'response'
end

get '/halt' do
  Process.kill :INT, 0
  'ok'
end
