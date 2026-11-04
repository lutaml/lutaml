#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Build LER package from EXPRESS schema
# This script demonstrates creating a self-contained LER package

require_relative "../lib/expressir"

puts "LER Package Builder Example"
puts "=" * 60
puts

# Input schema
SCHEMA_FILE = File.expand_path("ler/simple_schema.exp", __dir__)
OUTPUT_PACKAGE = File.expand_path("ler/simple_example.ler", __dir__)

unless File.exist?(SCHEMA_FILE)
  puts "Error: Schema file not found: #{SCHEMA_FILE}"
  exit 1
end

puts "Building LER package from: #{File.basename(SCHEMA_FILE)}"
puts "Output: #{File.basename(OUTPUT_PACKAGE)}"
puts

# Step 1: Parse schema
puts "Step 1: Parsing schema..."
parsed = Expressir::Express::Parser.from_file(SCHEMA_FILE)
puts "  ✓ Found #{parsed.schemas.size} schema(s)"

# Step 2: Build repository
puts "\nStep 2: Building repository..."
repo = Expressir::Model::Repository.new

# Initialize schemas if needed (for compatibility)
repo.instance_variable_set(:@schemas, []) if repo.schemas.nil?

parsed.schemas.each { |schema| repo.schemas << schema }
repo.resolve_all_references
puts "  ✓ Repository built with #{repo.schemas.size} schema(s)"

# Step 3: Show statistics
puts "\nStep 3: Repository statistics..."
stats = repo.statistics
puts "  Entities: #{stats[:total_entities]}"
puts "  Types: #{stats[:total_types]}"
puts "  Types by category:"
stats[:types_by_category].each do |category, count|
  puts "    #{category}: #{count}"
end

# Step 4: Export to package
puts "\nStep 4: Creating LER package..."
repo.export_to_package(
  OUTPUT_PACKAGE,
  name: "Simple Example Package",
  version: "1.0.0",
  description: "Example schema demonstrating LER packaging",
  express_mode: "include_all",
  resolution_mode: "resolved",
  serialization_format: "yaml",
)

file_size = File.size(OUTPUT_PACKAGE)
puts "  ✓ Package created: #{File.basename(OUTPUT_PACKAGE)}"
puts "  Size: #{file_size} bytes (#{(file_size / 1024.0).round(2)} KB)"

puts "\n#{'=' * 60}"
puts "Success! Package ready at: #{OUTPUT_PACKAGE}"
puts "\nTry these commands:"
puts "  ruby examples/ler_query.rb"
puts "  ruby examples/ler_stats.rb"
puts "  bundle exec expressir package info #{OUTPUT_PACKAGE}"
puts "  bundle exec expressir entity list --from #{OUTPUT_PACKAGE}"
puts
