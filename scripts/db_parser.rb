# Used to parse tags from a stackoverflow database
require 'colorize'

unless File.exists? "./so.sqlite" 
  puts "=============================================================================".red
  puts "ERROR ==> script cannot execute without the original db in the same directory"
  puts ""
  puts "FIX   ==> Make sure that the original db is in this dictory and is named so.sqlite"
  puts "=============================================================================".red
  abort
end

require 'sqlite3'

TAGS_ROW = 16
AUX_DB = "./auxiliary.sqlite"

# Remove the current auxiliary database
File.delete AUX_DB if File.exists? AUX_DB

sourceDB = SQLite3::Database.new("./so.sqlite")
destinationDB = SQLite3::Database.new(AUX_DB)

# Convenience methods

def tokenize_string(string)
  string.scan /<([^<>]+)>/
end

def get_pair(db, one, other)
  db.execute("SELECT * FROM tag_frequencies WHERE first_tag = '#{one}' AND second_tag = '#{other}'")
end

def insert_pair(db, one, other)
  db.execute("INSERT INTO tag_frequencies VALUES('#{one}','#{other}', 1)")
end

def set_pair(db, one, other, n)
  db.execute("UPDATE tag_frequencies SET count=#{n} WHERE first_tag = '#{one}' AND second_tag = '#{other}'")
end

def parse_columns(columns)
  columns_hash = {}
  columns.each_with_index do |column, i|
    columns_hash[column] = i
  end
  columns_hash
end

def _index_query(id, owner_display_name, body, title)
  "INSERT INTO posts_index(post_id, index_string) VALUES('#{id}', '#{owner_display_name} #{body} #{title}')"
end

# Create tags table
puts "Create tables tags and tag_frequencies".green
destinationDB.execute("CREATE TABLE tags(id INTEGER PRIMARY KEY, name TEXT)")
destinationDB.execute("CREATE TABLE tag_frequencies(first_tag TEXT, second_tag TEXT, count INTEGER)")

# Select all posts with tags
puts "Read tags from source db".green
rows = sourceDB.execute("SELECT * FROM posts WHERE tags <> 'NULL'")

tags = {}
rows.each do |row|
  # Each row is an array of attributes, we happen to know that tags is column 16
  raw_tags = row[TAGS_ROW]
  parsed_tags = tokenize_string(raw_tags)
  parsed_tags.each {|tag| tags[tag.first] = true}
  parsed_tags.combination(2).to_a.each do |pair|
    # For each combination, increment the frequency table
    flattened = pair.flatten.sort
    existing = get_pair(destinationDB, flattened[0], flattened[1])
    if existing.empty?
      insert_pair(destinationDB, flattened[0], flattened[1])
    else
      set_pair(destinationDB, flattened[0], flattened[1], existing.first[2].to_i + 1)
    end
  end
end



# Create tags
puts "Write tags to aux DB".green
queries = []
tags.each_key do |tag|
  queries.push "INSERT INTO tags (name) VALUES ('#{tag}')"
end

queries.each {|query| destinationDB.execute query}


#### Create the Full Text Search index
puts "Create posts index".green
destinationDB.execute("CREATE VIRTUAL TABLE posts_index USING fts4(post_id, index_string)")

posts_select_query = %Q(SELECT "posts"."id", "posts"."body", "posts"."title", "users"."display_name" FROM "users", "posts" WHERE "posts"."owner_user_id" = "users"."id")

columns = nil

index_queries = []

index_query_prototype = "INSERT INTO posts_index(post_id, index_string) VALUES(?, ?)"

puts "Gather post data".green
sourceDB.execute2(posts_select_query) do |row|
  if columns == nil
    columns = parse_columns(row)
    puts columns.inspect
  else
    owner_display_name = row[columns["display_name"]]
    body = row[columns["body"]]
    title = row[columns["title"]]
    id = row[columns["id"]]
    index_queries << [id, "#{body} #{title} #{owner_display_name}".gsub(/<([^<>]+)>/, "")]
  end
end

index_queries.each do |query| 
  begin
    destinationDB.execute(index_query_prototype, query)
  rescue Exception => ex
    puts ex.message.red
    # puts "Error in query: #{query}".red
  end
end

