#!/usr/bin/env ruby
# frozen_string_literal: true

# Metaschema Example - Ruby API
#
# This example demonstrates:
# - Building LXR packages from self-referential schemas
# - Handling XSD schemas that define XSD structure itself
# - Working with advanced schema patterns (NIST Metaschema)
# - Exploring meta-level type definitions
#
# Usage:
#   ruby examples/04-metaschema/ruby-api/example.rb

require "bundler/setup"
require "lutaml/xsd"
require "fileutils"

# Configuration
EXAMPLE_DIR = File.expand_path("..", __dir__)
CONFIG_PATH = File.join(EXAMPLE_DIR, "config.yml")
OUTPUT_PATH = File.join(EXAMPLE_DIR, "metaschema.lxr")

puts "=" * 80
puts "04-METASCHEMA: Ruby API Example"
puts "=" * 80
puts

# Step 1: Build LXR Package from Metaschema
# ------------------------------------------
puts "Step 1: Building LXR package from NIST Metaschema definition"
puts "-" * 80

config = YAML.load_file(CONFIG_PATH)
puts "Loaded configuration:"
puts "  Entry point: #{config['files'].size} file(s)"
puts "  Schema location mappings: #{config['schema_location_mappings']&.size || 0}"
puts "  Namespaces: #{config['namespace_mappings'].size}"
puts

puts "Building package..."
puts "(Processing self-referential schema...)"
start_time = Time.now

# Create repository with configuration
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

# Configure schema location mappings for includes
if config["schema_location_mappings"]
  mappings = config["schema_location_mappings"].map do |mapping|
    from = mapping["from"]
    to = File.expand_path(mapping["to"], EXAMPLE_DIR)
    is_pattern = mapping["pattern"] || false

    Lutaml::Xsd::SchemaLocationMapping.new(
      from: from,
      to: to,
      pattern: is_pattern,
    )
  end
  repository.instance_variable_set(:@schema_location_mappings, mappings)
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
    name: "NIST Metaschema Definition",
    version: "1.0",
    description: "XSD schema defining the Metaschema model structure",
  },
)

build_time = Time.now - start_time
file_size = File.size(OUTPUT_PATH)

puts "✓ Package created: #{File.basename(OUTPUT_PATH)}"
puts "  Size: #{(file_size / 1024.0).round(1)} KB"
puts "  Build time: #{build_time.round(2)} s"
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

# Step 3: Search for Metaschema Definition Types
# -----------------------------------------------
puts "Step 3: Searching for metaschema definition types"
puts "-" * 80

searcher = Lutaml::Xsd::TypeSearcher.new(loaded_repo)

search_terms = %w[Definition Assembly Field Flag Constraint]
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

# Step 4: Resolve Core Metaschema Types
# --------------------------------------
puts "Step 4: Resolving core metaschema types"
puts "-" * 80

# Find types with metaschema prefix
all_types = loaded_repo.all_type_names
meta_types = all_types.select do |t|
  t.start_with?("m:") || t.include?("Definition")
end.take(8)

puts "Found #{meta_types.size} metaschema-related types:"
puts

meta_types.each do |type_ref|
  result = loaded_repo.find_type(type_ref)

  if result&.resolved?
    definition = result.definition
    type_class = definition.class.name.split("::").last

    puts "  ✓ #{type_ref.split(':').last}"
    puts "    Type: #{type_class}"

    if definition.is_a?(Lutaml::Xsd::ComplexType)
      elements = definition.elements&.size || 0
      attrs = definition.attributes&.size || 0
      puts "    Elements: #{elements}, Attributes: #{attrs}"
    end
  else
    puts "  ✗ #{type_ref} - Not resolved"
  end
end
puts

# Step 5: Analyze Type Hierarchy
# -------------------------------
puts "Step 5: Analyzing type hierarchy"
puts "-" * 80

# Look for base types and extensions
complex_types = loaded_repo.all_type_names(category: :complex_type).take(10)

puts "Examining type structure (first 10 complex types):"
puts

complex_types.each do |type_name|
  result = loaded_repo.find_type(type_name)
  next unless result&.resolved?

  definition = result.definition
  next unless definition.is_a?(Lutaml::Xsd::ComplexType)

  # Check for base types
  next unless definition.complex_content || definition.simple_content

  content = definition.complex_content || definition.simple_content
  if content.extension
    puts "  #{type_name.split(':').last}"
    puts "    Extends: #{content.extension.base}"
  elsif content.restriction
    puts "  #{type_name.split(':').last}"
    puts "    Restricts: #{content.restriction.base}"
  end
end
puts

# Step 6: Explore Constraint-Related Types
# -----------------------------------------
puts "Step 6: Exploring constraint-related types"
puts "-" * 80

constraint_types = all_types.select { |t| t.include?("Constraint") }

puts "Constraint types (#{constraint_types.size} found):"
constraint_types.take(8).each do |ct|
  puts "  - #{ct}"
end
puts

# Step 7: Namespace Analysis
# ---------------------------
puts "Step 7: Namespace analysis"
puts "-" * 80

loaded_repo.all_namespaces.each do |ns|
  prefix = loaded_repo.namespace_to_prefix(ns)
  types = loaded_repo.all_type_names(namespace: ns)

  puts "Namespace: #{ns}"
  puts "  Prefix: #{prefix || '(default)'}"
  puts "  Types: #{types.size}"

  # Show type distribution
  complex = types.count { |t| loaded_repo.find_type(t)&.definition.is_a?(Lutaml::Xsd::ComplexType) }
  simple = types.count { |t| loaded_repo.find_type(t)&.definition.is_a?(Lutaml::Xsd::SimpleType) }

  puts "    Complex types: #{complex}"
  puts "    Simple types: #{simple}"
  puts
end

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "Key concepts demonstrated:"
puts "  ✓ Building packages from self-referential schemas"
puts "  ✓ Handling XSD schemas defining XSD structure"
puts "  ✓ Meta-level type definitions (types about types)"
puts "  ✓ Type hierarchy analysis"
puts "  ✓ Constraint type exploration"
puts
puts "NIST Metaschema:"
puts "  - Defines modeling language for data structures"
puts "  - Self-referential (defines its own structure)"
puts "  - Used by OSCAL and other NIST standards"
puts
puts "Output files:"
puts "  - #{OUTPUT_PATH}"
puts "=" * 80
