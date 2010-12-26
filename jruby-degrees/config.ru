require 'rubygems'
require 'lib/degrees'

set :run,         false
set :environment, :production

run Sinatra::Application
