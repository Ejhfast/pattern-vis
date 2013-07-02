require 'rubygems'
require 'sinatra'
require 'haml'
require 'mongoid'
require 'ripper'
require 'nokogiri'

# Database stuff
#Mongoid.load!("mongoid.yaml", :development)
Mongoid.load!("test.yaml", :development)
#Mongoid.load!("rails_test_db.yaml", :development)


class CPattern
  include Mongoid::Document
  field :pattern, type: Array
  field :n, type: Integer
  field :count, type: Integer
  field :code, type: Array, default: []
  field :files, type: Array, default: []
  field :projects, type: Array, default: []
  field :info, type: Integer
  field :info_d, type: Float
  field :pmi, type: Integer
  field :p_count, type: Integer
  field :hash_str, type: String
  field :names, type: Hash
  
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

class Line
  include Mongoid::Document
  field :file, type: String
  field :text, type: String
  field :number, type: Integer
  
  def around(n)
    Line.where(:file => file, :number => {$gt => number - n, $lt => number + n})
  end
  
end

def parse_ri(query)
  ds = Hash.new
  out = `ri --no-page -f html #{query}`
  doc = Nokogiri::HTML(out)
  nodes = doc.css("*")
  nex = nodes.shift
  while !nodes.empty? && !nex.css_path.include?("h1")
    nex = nodes.shift
  end
  title = nex.content
  puts title
  signature = []
  description = []
  option = title.include?("#") ? title : nil
  
  nex = nodes.shift
  while !nodes.empty?
    if nex.css_path.include?("h3") || option == title
      option = nex.content unless option == title
      nex = nodes.shift
      while !nodes.empty? && !nex.css_path.include?("pre")
        nex = nodes.shift
      end
      while !nodes.empty? && nex.css_path.include?("pre")
        signature.push(nex.content)
        nex = nodes.shift
      end
      while !nodes.empty? && !nex.css_path.include?("h3")
        description.push(nex.to_html)
        nex = nodes.shift
      end
      description = description.first(description.size-1) unless description.size == 0
      ds[[title,option]] = {:signature => signature, :description => description}
      description = []
      signature = []
      option = nil
    else
      nex = nodes.shift
    end
  end
  ds.map{|k,v| v}.first
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

def color_token(tk, pre = nil)
  lookup = Hash.new(Hash.new(false))
  lookup[:on_symber] = Hash.new("#B0BCFF")
  lookup[:on_ident] = Hash.new("#E5B0FF")
  lookup[:on_symbeg] = Hash.new("#91FDFF")
  lookup[:on_ident]["var"] = pre && pre[1] == :symbeg ? "#91FDFF" : "#fff"
  lookup[:on_ident]["@var"] = "#8FFF98"
  lookup[:on_ident]["$var"] = "#8F96FF"
  lookup[:on_tstring_beg] = Hash.new("#7AFF8C")
  lookup[:on_tstring_content] = Hash.new("#7AFF8C")
  lookup[:on_tstring_end] = Hash.new("#7AFF8C")
  lookup[:on_op] = Hash.new("#FF7A7A")
  lookup[:on_const] = Hash.new("#F2FF7A")
  lookup[:on_kw] = Hash.new("#7F7AFF")
  lookup[:on_comment] = Hash.new("#999")
  if lookup[tk[1]][tk[2]]
    tk[2] = "<span style='color:#{lookup[tk[1]][tk[2]]};'>"+CGI::escapeHTML(tk[2])+"</span>"
  end
  tk[2]
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
  @count = params[:count] ? params[:count].to_i : 2
  @proj_count = params[:projects] ? params[:projects].to_i : 2
  @info_d = params[:info_d] ? params[:info_d].to_i : 6
  @pmi = params[:pmi] ? params[:pmi].to_i : 50
  @info = params[:info] ? params[:info].to_i : 9
  @min_lines = params[:min_l] ? params[:min_l].to_i : 1
  st = Stats.all.first 
  @stats = {:loc => st[:loc], :projects => st[:projects]}
  @total_size = CPattern.all.size
  req = CPattern.where(:count => {:$gte => @count}, :p_count => {:$gte => @proj_count}, :info => {:$gte => @info}, :info_d => {:$gte => @info_d }, :n => {:$gte => @min_lines}).sort(:count => -1)
  @data = req.select{|x| x.pmi > @pmi || x.n == 1}
  haml :combine, :layout => :'layouts/application'
end

get '/list' do
  @count = params[:count] ? params[:count].to_i : 2
  @proj_count = params[:projects] ? params[:projects].to_i : 2
  @info_d = params[:info_d] ? params[:info_d].to_i : 3
  @pmi = params[:pmi] ? params[:pmi].to_i : 50
  @info = params[:info] ? params[:info].to_i : 5
  req = CPattern.where(:count => {:$gte => @count}, :p_count => {:$gte => @proj_count}, :info => {:$gte => @info}, :info_d => {:$gte => @info_d }).sort(:count => -1)
  @data = req.select{|x| x.pmi > @pmi || x.n == 1}.sort_by{|x| x.info_d * -1}
  @out_str = ""
  count = 1
  @data.each do |p|
    @out_str+="#{count}.\n"
    @out_str+=p.pattern.join("\n")
    @out_str+="\n\n"
    count += 1
  end
  headers["Content-type"] = "text";
  @out_str
end

get '/query/:q' do
  resp = parse_ri(params[:q])
  @q = params[:q]
  @des = resp[:description]
  haml :query, :layout => :'layouts/application'
end

get '/freq' do
  loader = get_data("data/freq_data")
  @stats = loader[0]
  @data = loader[1]
  haml :freq, :layout => :'layouts/application'
end

get '/file' do
 file = params[:f].gsub("data/","data//")
 @txt = Line.where(:file => file).sort(:number => 1).map{|x| params[:hl].to_i == x.number + 1 ? "<span class='highlight'>"+x.text+"</span>" : x.text}.join("\n")
 haml :file, :layout => :'layouts/application'
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
