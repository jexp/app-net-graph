require 'rubygems'
require 'open-uri'
require "json"
require 'cypher'

class AppNet 

def prepare_add_user(id)
# returns 0 when created and 1 if it was already there
{:query=>
"start n=node:node_auto_index(name={id}) 
 with count(*) as c 
 where c=0 
 create x={name:{id}} 
 return c", 
 :params => {:id => id}} 
end

def add_user(id)
  p=prepare_add_user(id)
  @cypher.query(p[:query],p[:params])
end

def add_all
  prepared = @people.keys.map { |k|  prepare_add_user(k) }
  @cypher.batch(prepared)
end

def init_graph
  @cypher.clean
  props=@people.keys.map { |k| {:name => k } }
  @cypher.query("create n={people}", { :people=>props})
end

def add_followers(id,followers)
  prepared=followers.map do |f|
    {:query=> "start user=node:node_auto_index(name={id}), follower=node:node_auto_index(name={f_id}) create user<-[:FOLLOWS]-follower",
     :params=>{:id=>id, :f_id=>f}}
   end
   @cypher.batch(prepared)
end

PEOPLE="../people.json"
def followers_file(id)
  "../data/#{id}"
end

def create_graph
  init_graph
  @people.keys.map do |id|
    if File.exists?(followers_file(id))
      followers = IO.read(followers_file(id)).split(/\n/)
      add_followers(id,followers)
    end
  end
end
def initialize
  @people=JSON.parse(IO.read(PEOPLE))
  @cypher=Cypher.new
end

def followers(id) 
  return if @people[id]
  url="https://alpha.app.net/#{id}/followers/"
  cnt = 0
  open(url) do |io|
    page=io.read
    open(followers_file(id),"w") do |followers|
      cnt = page.scan(/class="username"><a href="\/(.+?)"/) { |f| followers.puts(f); @people[f]=!!@people[f]; f }.size
    end
  end
  @people[id]=true
  puts "#{id}<-#{cnt} total #{@people.size} todo #{@people.count{ |k,v| !v}}"
  open(PEOPLE,"w") { |f| f.puts @people.to_json }
end

def scan_next
  id = @people.find { |k,v| !v }
  return false unless id
  followers(id[0])
  return true
end

end
