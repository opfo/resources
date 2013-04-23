# Used to parse tags from a stackoverflow database
require 'sqlite3'

TAGS_ROW = 16
AUX_DB = "./auxiliary.sqlite"

# Remove the current auxiliary database
File.delete AUX_DB if File.exists? AUX_DB

sourceDB = SQLite3::Database.new("./so.sqlite")
destinationDB = SQLite3::Database.new(AUX_DB)

def tokenize_string(string)
  string.scan /<(\w+)>/
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

# Create tags table
destinationDB.execute("CREATE TABLE tags(id INTEGER PRIMARY KEY, name TEXT)")
destinationDB.execute("CREATE TABLE tag_frequencies(first_tag TEXT, second_tag TEXT, count INTEGER)")

# Select all posts with tags
rows = sourceDB.execute("SELECT * FROM posts WHERE tags <> 'NULL'")

tags = {}
rows.each do |row|
  # Each row is an array of attributes, we happen to know that tags is column 16
  raw_tags = row[TAGS_ROW]
  parsed_tags = tokenize_string(raw_tags)
  parsed_tags.each {|tag| tags[tag.first] = true}
  parsed_tags.combination(2).to_a.each do |pair|
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
queries = []
tags.each_key do |tag|
  queries.push "INSERT INTO tags (name) VALUES ('#{tag}')"
end

queries.each {|query| destinationDB.execute query}
