#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Query LER package for entities and types
# This script demonstrates querying an existing LER package

require_relative "../lib/expressir"

PACKAGE_FILE = File.expand_path("ler/simple_example.ler", __dir__)

unless File.exist?(PACKAGE_FILE)
  puts "Error: Package not found: #{PACKAGE_FILE}"
  puts "Run 'ruby examples/ler_build.rb' first to create the package."
  exit 1
end

puts "LER Package Query Example"
puts "=" * 60
puts "Package: #{File.basename(PACKAGE_FILE)}"
puts

# Load package
puts "Loading package..."
start_time = Time.now
repo = Expressir::Model::Repository.from_package(PACKAGE_FILE)
load_time = ((Time.now - start_time) * 1000).round(2)
puts "  ✓ Loaded in #{load_time}ms"
puts

# Query 1: Find specific entity
puts "Query 1: Find entity 'simple_example.product'"
puts "-" * 60
entity = repo.find_entity(qualified_name: "simple_example.product")
if entity
  puts "  ✓ Found: #{entity.id}"
  puts "  Schema: #{entity.parent.id}"
  puts "  Path: #{entity.path}"
  if entity.attributes&.any?
    puts "  Attributes:"
    entity.attributes.each do |attr|
      puts "    - #{attr.id}"
    end
  end
else
  puts "  ✗ Not found"
end
puts

# Query 2: List all entities
puts "Query 2: List all entities"
puts "-" * 60
entities = repo.list_entities(format: :hash)
puts "  Total entities: #{entities.size}"
entities.each do |e|
  puts "    #{e[:schema]}.#{e[:id]}"
end
puts

# Query 3: Find specific type
puts "Query 3: Find type 'simple_example.product_status'"
puts "-" * 60
type = repo.find_type(qualified_name: "simple_example.product_status")
if type
  puts "  ✓ Found: #{type.id}"
  puts "  Schema: #{type.parent.id}"
end
puts

# Query 4: List types by category
puts "Query 4: List SELECT types"
puts "-" * 60
select_types = repo.list_types(category: "select", format: :hash)
puts "  Total SELECT types: #{select_types.size}"
select_types.each do |t|
  puts "    #{t[:schema]}.#{t[:id]} [#{t[:category]}]"
end
puts

# Query 5: List ENUMERATION types
puts "Query 5: List ENUMERATION types"
puts "-" * 60
enum_types = repo.list_types(category: "enumeration", format: :hash)
puts "  Total ENUMERATION types: #{enum_types.size}"
enum_types.each do |t|
  puts "    #{t[:schema]}.#{t[:id]} [#{t[:category]}]"
end
puts

puts "=" * 60
puts "Query examples complete!"
puts
