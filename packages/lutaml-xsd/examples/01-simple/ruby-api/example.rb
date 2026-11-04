#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Schemas Example - Ruby API
#
# This example demonstrates:
# - Building an LXR package from simple schemas
# - Searching for types
# - Resolving type references
# - Package inspection
#
# Usage:
#   ruby examples/01-simple/ruby-api/example.rb

require "bundler/setup"
require "lutaml/xsd"
require "fileutils"

# Configuration
EXAMPLE_DIR = File.expand_path("..", __dir__)
CONFIG_PATH = File.join(EXAMPLE_DIR, "config.yml")
OUTPUT_PATH = File.join(EXAMPLE_DIR, "simple.lxr")

puts "=" * 80
puts "01-SIMPLE: Ruby API Example"
puts "=" * 80
puts

# Step 1: Build LXR Package
# -------------------------
puts "Step 1: Building LXR package from configuration"
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
    name: "Simple Example Schemas",
    version: "1.0.0",
    description: "Basic person and company schemas for demonstration",
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

# Step 3: Search for Types
# -------------------------
puts "Step 3: Searching for types"
puts "-" * 80

searcher = Lutaml::Xsd::TypeSearcher.new(loaded_repo)

search_terms = %w[Person Company Address Type]
search_terms.each do |term|
  puts "Searching for '#{term}'..."
  results = searcher.search(term, in_field: "name", limit: 5)

  if results.empty?
    puts "  No results found"
  else
    results.each do |result|
      puts "  • #{result.qualified_name} (#{result.category})"
      puts "    Relevance: #{result.relevance_score}"
    end
  end
  puts
end

# Step 4: Resolve Type References
# --------------------------------
puts "Step 4: Resolving type references"
puts "-" * 80

type_refs = ["p:PersonType", "c:CompanyType", "p:AddressType", "p:EmailType"]
type_refs.each do |ref|
  puts "Resolving '#{ref}'..."
  result = loaded_repo.find_type(ref)

  if result&.resolved?
    definition = result.definition
    puts "  ✓ Found: #{definition.class.name.split('::').last}"
    puts "    Namespace: #{result.namespace}"
    puts "    Schema: #{File.basename(result.schema_file)}"

    # Show type details
    case definition
    when Lutaml::Xsd::ComplexType
      puts "    Elements: #{definition.elements&.size || 0}"
      puts "    Attributes: #{definition.attributes&.size || 0}"
    when Lutaml::Xsd::SimpleType
      puts "    Base type: #{definition.restriction&.base || 'unknown'}"
    end
  else
    puts "  ✗ Not found"
    puts "    Error: #{result&.error_message || 'Type does not exist'}"
  end
  puts
end

# Step 5: Explore Namespaces
# ---------------------------
puts "Step 5: Exploring namespaces"
puts "-" * 80

loaded_repo.all_namespaces.each do |ns|
  prefix = loaded_repo.namespace_to_prefix(ns)
  types = loaded_repo.all_type_names(namespace: ns)

  puts "Namespace: #{ns}"
  puts "  Prefix: #{prefix}"
  puts "  Types (#{types.size}):"
  types.each do |type_name|
    puts "    - #{type_name}"
  end
  puts
end

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "Key concepts demonstrated:"
puts "  ✓ Building LXR packages from YAML configuration"
puts "  ✓ Package serialization and loading"
puts "  ✓ Type searching with relevance ranking"
puts "  ✓ Type resolution by qualified name"
puts "  ✓ Namespace exploration"
puts
puts "Output files:"
puts "  - #{OUTPUT_PATH}"
puts "=" * 80
