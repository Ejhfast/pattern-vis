require 'rubygems'
require 'sinatra'
require 'haml'
require 'mongoid'

# Database stuff
Mongoid.load!("mongoid.yaml", :development)

class CPattern
  include Mongoid::Document
  field :pattern, type: Array
  field :n, type: Integer
  field :count, type: Integer
  field :code, type: Array, default: []
  field :files, type: Array, default: []
  field :projects, type: Array, default: []
  field :bits, type: Integer
  field :p_count, type: Integer
  
  index({ pattern: 1, n: 1 }, { unique: true })
    
  scope :of_n, ->(n){where(n: n)}
  scope :including, ->(p){where(:pattern.in => [ p ])} 
end

class Stats
  include Mongoid::Document
  include Mongoid::Timestamps
  field :loc, type: Integer, default: 0
  field :projects, type: Array, default: []
  field :options, type: Array, default: []
end

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

DATA = nil

# Application routes
get '/' do
  @count = params[:count] ? params[:count].to_i : 2
  @count = 2 if @count < 2
  @proj_count = params[:projects] ? params[:projects].to_i : 2
  @bits = params[:bits] ? params[:bits].to_i : 5
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

get '/all' do
  @count = params[:count] ? params[:count].to_i : 1
  @proj_count = params[:projects] ? params[:projects].to_i : 1
  @bits = params[:bits] ? params[:bits].to_i : 100
  @pmf = params[:pmf] ? params[:pmf].to_i : 1
  @info = params[:info] ? params[:info].to_i : 100
  @stats = Stats.all.first #{:loc => 180000, :projects => ["lots_proj"]}
  @total_size = CPattern.all.size
  req = CPattern.where(:p_count => {:$gt => @proj_count}, :bits => {:$gt => @bits }, :count => {:$gt => @count}, :info => {:$gt => @info}).sort(:count => -1)
  @data = req.select{|x| x.pmf > @pmf || x.n == 1}
  haml :combine, :layout => :'layouts/application'
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