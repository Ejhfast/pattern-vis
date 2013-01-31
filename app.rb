require 'rubygems'
require 'sinatra'
require 'haml'

# Helpers
require './lib/render_partial'

# Set Sinatra variables
set :app_file, __FILE__
set :root, File.dirname(__FILE__)
set :views, 'views'
set :public_folder, 'public'
set :haml, {:format => :html5} # default Haml format is :xhtml

def get_data(data_file)
  Marshal.load(File.new(data_file).to_a.join)
end

# Application routes
get '/' do
  loader = get_data("data/data15")
  @stats = loader[0]
  @data = loader[1]
  haml :index, :layout => :'layouts/application'
end

get '/freq' do
  loader = get_data("data/freq_data")
  @stats = loader[0]
  @data = loader[1]
  haml :freq, :layout => :'layouts/application'
end

get '/about' do
  haml :about, :layout => :'layouts/page'
end