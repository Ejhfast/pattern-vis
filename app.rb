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
  @count = params[:count] ? params[:count].to_i : 2
  @count = 2 if @count < 2
  @proj_count = params[:projects] ? params[:projects].to_i : 2
  loader = get_data("data/"+params[:file]) rescue nil
  if loader
    @stats = loader[0]
    @data = loader[1]
    @len = @data.first.size - 2
  else
    @files = Dir["data/*"].to_a.map do |f|
      colors = {"--all-ast" => "red", "--junk" => "blue",
                "--str" => "green", "--var" => "orange", 
                "--fun" => "purple", "--fargs" => "yellow", 
                "--lit" => "turq"}
      opts = get_data(f)[0][:options].select{|x| x != "--all-ast" && x != "--just-calls"}
      {:name => f.split("/")[1], :opts => opts.map{|x| [x.split("--")[1], colors[x]]}}
    end
  end
  haml :index, :layout => :'layouts/application'
end

get '/freq' do
  loader = get_data("data/freq_data")
  @stats = loader[0]
  @data = loader[1]
  haml :freq, :layout => :'layouts/application'
end

get '/m3' do
  loader = get_data("data/data3chain_no_argsA")
  @stats = loader[0]
  @data = loader[1]
  haml :m3, :layout => :'layouts/application'
end

get '/about' do
  haml :about, :layout => :'layouts/page'
end