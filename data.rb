require 'mongoid'

# Database stuff
Mongoid.load!("mongoid.yaml", :development)

class Pattern
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