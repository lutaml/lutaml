#!/usr/bin/env ruby
# frozen_string_literal: true

# UnitsML Example - Ruby API
#
# This example demonstrates:
# - Building LXR packages from scientific units standards
# - Working with specialized vocabulary (units of measure)
# - Type resolution in scientific domains
#
# Usage:
#   ruby examples/03-unitsml/ruby-api/example.rb

require "bundler/setup"
require "lutaml/xsd"
require "fileutils"

# Configuration
EXAMPLE_DIR = File.expand_path("..", __dir__)
CONFIG_PATH = File.join(EXAMPLE_DIR, "config.yml")
OUTPUT_PATH = File.join(EXAMPLE_DIR, "unitsml.lxr")

puts "=" * 80
puts "03-UNITSML: Ruby API Example"
puts "=" * 80
puts

# Step 1: Build LXR Package
# -------------------------
puts "Step 1: Building LXR package from UnitsML schema"
puts "-" * 80

config = YAML.load_file(CONFIG_PATH)
puts "Loaded configuration:"
puts "  Files: #{config['files'].size}"
puts "  Namespaces: #{config['namespace_mappings'].size}"
puts

puts "Building package..."
start_time = Time.now

# Create repository from config
repository = Lutaml::Xsd::SchemaRepository.new

# Set schema files (as absolute paths)
schema_files = config["files"].map { |f| File.expand_path(f, EXAMPLE_DIR) }
repository.instance_variable_set(:@files, schema_files)

# Configure namespace mappings
config["namespace_mappings"].each do |mapping|
  repository.configure_namespace(
    prefix: mapping["prefix"],
    uri: mapping["uri"],
  )
end

# Parse and resolve schemas
repository.parse.resolve

# Create package
repository.to_package(
  OUTPUT_PATH,
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal,
  metadata: {
    name: "UnitsML Schemas",
    version: "1.0-csd04",
    description: "OASIS UnitsML standard for units of measure",
  },
)

build_time = Time.now - start_time
file_size = File.size(OUTPUT_PATH)

puts "✓ Package created: #{File.basename(OUTPUT_PATH)}"
puts "  Size: #{(file_size / 1024.0).round(1)} KB"
puts "  Build time: #{(build_time * 1000).round(1)} ms"
puts

# Step 2: Load and Inspect Package
# ---------------------------------
puts "Step 2: Loading and inspecting package"
puts "-" * 80

start_time = Time.now
loaded_repo = Lutaml::Xsd::SchemaRepository.from_package(OUTPUT_PATH)
# Ensure repository is fully resolved (builds type index)
loaded_repo.resolve
load_time = Time.now - start_time

puts "✓ Package loaded in #{(load_time * 1000).round(1)} ms"
puts

stats = loaded_repo.statistics
puts "Repository statistics:"
puts "  - Total schemas: #{stats[:total_schemas]}"
puts "  - Total types: #{stats[:total_types]}"
puts "  - Namespaces: #{stats[:total_namespaces]}"
puts

# Step 3: Search for Unit-Related Types
# --------------------------------------
puts "Step 3: Searching for unit-related types"
puts "-" * 80

searcher = Lutaml::Xsd::TypeSearcher.new(loaded_repo)

search_terms = %w[Unit Quantity Dimension Prefix Symbol]
search_terms.each do |term|
  puts "Searching for '#{term}'..."
  results = searcher.search(term, in_field: "name", limit: 5)

  if results.empty?
    puts "  No results found"
  else
    results.each do |result|
      puts "  • #{result.qualified_name}"
      puts "    Category: #{result.category}, Relevance: #{result.relevance_score}"
    end
  end
  puts
end

# Step 4: Resolve Unit Definition Types
# --------------------------------------
puts "Step 4: Resolving unit definition types"
puts "-" * 80

# Try to find unit-related types (namespace prefix may vary)
all_types = loaded_repo.all_type_names
unit_types = all_types.grep(/(Unit|Quantity|Dimension)/).take(5)

puts "Found #{unit_types.size} unit-related types (showing details):"
puts

unit_types.each do |type_ref|
  puts "Resolving '#{type_ref}'..."
  result = loaded_repo.find_type(type_ref)

  if result&.resolved?
    definition = result.definition
    puts "  ✓ Found: #{definition.class.name.split('::').last}"
    puts "    Namespace: #{result.namespace}"

    if definition.is_a?(Lutaml::Xsd::ComplexType)
      puts "    Elements: #{definition.elements&.size || 0}"
      puts "    Attributes: #{definition.attributes&.size || 0}"
    elsif definition.is_a?(Lutaml::Xsd::SimpleType)
      puts "    Type: Simple type definition"
    end
  else
    puts "  ✗ Not resolved"
  end
  puts
end

# Step 5: Explore Type Categories
# --------------------------------
puts "Step 5: Exploring type categories"
puts "-" * 80

categories = %i[complex_type simple_type element]
categories.each do |category|
  types = loaded_repo.all_type_names(category: category)

  puts "#{category.to_s.split('_').map(&:capitalize).join(' ')}s: #{types.size}"
  if types.size.positive?
    puts "  Examples (first 5):"
    types.take(5).each do |type_name|
      puts "    - #{type_name}"
    end
  end
  puts
end

# Step 6: Namespace Summary
# --------------------------
puts "Step 6: Namespace summary"
puts "-" * 80

summary = loaded_repo.namespace_summary
summary.each do |ns_info|
  puts "Namespace: #{ns_info[:uri]}"
  puts "  Prefix: #{ns_info[:prefix] || '(default)'}"
  puts "  Types: #{ns_info[:types]}"
  puts
end

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "Key concepts demonstrated:"
puts "  ✓ Building packages from scientific standards"
puts "  ✓ Working with specialized vocabulary"
puts "  ✓ Type discovery and categorization"
puts "  ✓ Namespace analysis"
puts
puts "UnitsML Standard:"
puts "  - Defines units of measure"
puts "  - Supports scientific calculations"
puts "  - Standardized vocabulary"
puts
puts "Output files:"
puts "  - #{OUTPUT_PATH}"
puts "=" * 80
