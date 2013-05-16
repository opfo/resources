# Used to parse tags from a stackoverflow database
require 'colorize'
require 'debugger'

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
  db.execute("UPDATE tag_frequencies SET counter=#{n} WHERE first_tag = '#{one}' AND second_tag = '#{other}'")
end

# Creates a hash column_name => column_index
# ["apa", "bepa", "cepa"]
# => {"apa": 0, "bepa": 1, "cepa": 2}
def parse_columns(columns)
  columns_hash = {}
  columns.each_with_index do |column, i|
    columns_hash[column] = i
  end
  columns_hash
end

# Create tags table
puts "Create tables tags and tag_frequencies".green
destinationDB.execute("CREATE TABLE tags(id INTEGER PRIMARY KEY, name TEXT, counter INTEGER)")
destinationDB.execute("CREATE TABLE tag_frequencies(first_tag TEXT, second_tag TEXT, counter INTEGER)")

# Select all posts with tags
puts "Read tags from source db".green
rows = sourceDB.execute("SELECT * FROM posts WHERE tags <> 'NULL'")

tags = {}
tag_frequencies = {}
rows.each do |row|
  # Each row is an array of attributes, we happen to know that tags is column 16
  raw_tags = row[TAGS_ROW]
  parsed_tags = tokenize_string(raw_tags)
  parsed_tags.each do |tag|
    if tags.has_key? tag
      tags[tag] += 1
    else
      tags[tag] = 1
    end
  end
  parsed_tags.combination(2).to_a.each do |pair|
    # For each combination, increment the frequency table
    flattened = pair.flatten.sort
    key = [flattened[0], flattened[1]]
    if tag_frequencies.has_key? key
      tag_frequencies[key] += 1
    else
      tag_frequencies[key] = 1
    end
    # existing = get_pair(destinationDB, flattened[0], flattened[1])

    # if existing.empty?
    #   insert_pair(destinationDB, flattened[0], flattened[1])
    # else
    #   set_pair(destinationDB, flattened[0], flattened[1], existing.first[2].to_i + 1)
    # end
  end
end



# Create tags
puts "Write tags to aux DB".green
tags_write_query = "INSERT INTO tags (name, counter) VALUES(?,?)"
queries = []
tags.each do |tag, frequency|
  queries.push [tag, frequency]
end

queries.each {|args| destinationDB.execute(tags_write_query, args)}

# Create tag frequencies
puts "Write tag frequencies to aux DB".green
tag_frequency_write_query = "INSERT INTO tag_frequencies(first_tag, second_tag, counter) VALUES (?,?,?)"
tag_frequencies.each do |pair, value|
  destinationDB.execute(tag_frequency_write_query, [pair[0], pair[1], value])
end

#### 
##    Create the Full Text Search indexes
####

#### Posts

puts "Create posts index".green
destinationDB.execute("CREATE VIRTUAL TABLE posts_index USING fts4(object_id, main_index_string, aux_index_string, tags)")

posts_select_query = 
  %Q(
    SELECT "posts"."id", "posts"."body", "posts"."title", "users"."display_name", "posts"."tags" 
    FROM "users", "posts" 
    WHERE "posts"."owner_user_id" = "users"."id"
    )
answers_select_query = 
  %Q(
    SELECT "posts"."id", "posts"."parent_id", "posts"."body", "posts"."title"
    FROM "posts"
    WHERE "posts"."post_type_id" = 2
    )
columns = nil

index_queries = {}

index_query_prototype = "INSERT INTO posts_index(object_id, main_index_string, aux_index_string, tags) VALUES(?, ?, ?, ?)"

puts "Gather all posts data".green
sourceDB.execute2(posts_select_query) do |row|
  if columns == nil
    columns = parse_columns(row)
    puts columns.inspect
  else
    owner_display_name = row[columns["display_name"]]
    body  = row[columns["body"]]
    title = row[columns["title"]]
    id    = row[columns["id"]]
    tags  = tokenize_string(row[columns["tags"]]).join(" ")
    main_index_string = "#{body} #{title} #{owner_display_name}".gsub(/<([^<>]+)>/, "")
    index_queries[id] = [id, main_index_string, "", tags]
  end
end

puts "Gather answer data".green

columns = nil
sourceDB.execute2(answers_select_query) do |row|
  if columns == nil
    columns = parse_columns(row)
  else
    parent_id = row[columns["parent_id"]]
    body = row[columns["body"]]
    title = row[columns["title"]]
    index_string = " #{body} #{title}".gsub(/<([^<>]+)>/, "")
    question_query = index_queries[parent_id]
    if question_query
      current_answer_string = question_query[2]
      current_answer_string ||= ""
      question_query[2] = current_answer_string + index_string
    end
  end
end

index_queries.each do |id, query| 
  begin
    destinationDB.execute(index_query_prototype, query)
  rescue Exception => ex
    puts ex.message.red
  end
end


#### Users

puts "Create users index".green
destinationDB.execute("CREATE VIRTUAL TABLE users_index USING fts4(object_id, index_string)")

users_select_query = %Q(SELECT "users"."id", "users"."display_name" FROM "users")

user_index_query_prototype = "INSERT INTO users_index(object_id, index_string) VALUES(?, ?)"

puts "Gather user data".green

user_index_queries = []

columns = nil
sourceDB.execute2(users_select_query) do |row|
  if columns.nil?
    columns = parse_columns(row)
  else
    user_id = row[columns["id"]]
    display_name = row[columns["display_name"]]
    user_index_queries << [user_id, display_name]
  end
end

puts "Write user data".green

user_index_queries.each do |query|
  begin
    destinationDB.execute(user_index_query_prototype, query)
  rescue Exception => ex
    puts ex.message.red
  end
end


#### Create users_votes
puts "Create users_votes".green

users_votes_query = %Q{
  CREATE TABLE "users_votes" (
   "user_id" integer,
   "post_id" integer,
   "upvote" integer,
  PRIMARY KEY("user_id","post_id")
)
}

destinationDB.execute(users_votes_query)

puts "Done".green


