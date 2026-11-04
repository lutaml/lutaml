#!/usr/bin/env ruby
# frozen_string_literal: true

# Urban Function Example - Ruby API
#
# This example demonstrates:
# - Building LXR packages from complex schemas with many imports/includes
# - Handling schema location mappings
# - Working with large schema sets (i-UR standard)
# - Advanced type resolution
#
# Usage:
#   ruby examples/02-urban-function/ruby-api/example.rb

require "bundler/setup"
require "lutaml/xsd"
require "fileutils"

# Configuration
EXAMPLE_DIR = File.expand_path("..", __dir__)
CONFIG_PATH = File.join(EXAMPLE_DIR, "config.yml")
OUTPUT_PATH = File.join(EXAMPLE_DIR, "urban_function.lxr")

puts "=" * 80
puts "02-URBAN-FUNCTION: Ruby API Example"
puts "=" * 80
puts

# Step 1: Build LXR Package from Complex Schema
# ----------------------------------------------
puts "Step 1: Building LXR package from i-UR urban function schema"
puts "-" * 80

config = YAML.load_file(CONFIG_PATH)
metadata_config = config["metadata"] || {}
build_config = config["build"] || {}

puts "Loaded configuration:"
puts "  Name: #{metadata_config['name'] || 'N/A'} v#{metadata_config['version'] || 'N/A'}"
puts "  Entry points: #{config['files'].size} file(s)"
puts "  Schema location mappings: #{config['schema_location_mappings']&.size || 0}"
puts "  Namespaces: #{config['namespace_mappings'].size}"
puts

puts "Building package..."
puts "(This may take a moment due to schema complexity...)"
start_time = Time.now

# Create repository with configuration
repository = Lutaml::Xsd::SchemaRepository.new

# Set schema files (as absolute paths)
schema_files = config["files"].map { |f| File.expand_path(f, EXAMPLE_DIR) }
repository.add_schema_files(schema_files)

# Configure namespace mappings
config["namespace_mappings"].each do |mapping|
  repository.configure_namespace(
    prefix: mapping["prefix"],
    uri: mapping["uri"],
  )
end

# Configure schema location mappings for imports/includes
if config["schema_location_mappings"]
  mappings = config["schema_location_mappings"].map do |mapping|
    from = mapping["from"]
    to = File.expand_path(mapping["to"], EXAMPLE_DIR)
    is_pattern = mapping["pattern"] || false

    {
      from: from,
      to: to,
      pattern: is_pattern,
    }
  end
  repository.configure_schema_location_mappings(mappings)
end

# Parse and resolve schemas
repository.parse.resolve

# Use build options from config
xsd_mode = (build_config["xsd_mode"] || "include_all").to_sym
resolution_mode = (build_config["resolution_mode"] || "resolved").to_sym
serialization_format = (build_config["serialization_format"] || "marshal").to_sym

# Create package with all metadata from config
repository.to_package(
  OUTPUT_PATH,
  xsd_mode: xsd_mode,
  resolution_mode: resolution_mode,
  serialization_format: serialization_format,
  metadata: {
    name: metadata_config["name"],
    version: metadata_config["version"],
    description: metadata_config["description"],
    title: metadata_config["title"] || metadata_config["name"],
    homepage: metadata_config["homepage"],
    repository: metadata_config["repository"],
    documentation: metadata_config["documentation"],
    license: metadata_config["license"],
    authors: metadata_config["authors"],
    tags: metadata_config["tags"],
    appearance: config["appearance"],
    links: config["links"],
  }.compact,
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

# Step 3: Search for Urban Planning Types
# ----------------------------------------
puts "Step 3: Searching for GML types in the package"
puts "-" * 80

searcher = Lutaml::Xsd::TypeSearcher.new(loaded_repo)

search_terms = %w[gml Coverage Geometry Point Feature]
search_terms.each do |term|
  puts "Searching for '#{term}'..."
  results = searcher.search(term, in_field: "name", limit: 5)

  if results.empty?
    puts "  No results found"
  else
    results.each do |result|
      puts "  • #{result.qualified_name}"
      puts "    Category: #{result.category}"
      puts "    Relevance: #{result.relevance_score}"
    end
  end
  puts
end

# Step 4: Resolve Specific Urban Function Types
# ----------------------------------------------
puts "Step 4: Resolving GML types"
puts "-" * 80

type_refs = [
  "gml:AbstractGMLType",
  "gml:FeaturePropertyType",
  "gml:AbstractCoverageType",
  "gml:PointType",
]

type_refs.each do |ref|
  puts "Resolving '#{ref}'..."
  result = loaded_repo.find_type(ref)

  if result&.resolved?
    definition = result.definition
    puts "  ✓ Found: #{definition.class.name.split('::').last}"
    puts "    Namespace: #{result.namespace}"
    puts "    Schema: #{File.basename(result.schema_file)}"

    if definition.is_a?(Lutaml::Xsd::ComplexType)
      puts "    Elements: #{definition.elements&.size || 0}"
      puts "    Attributes: #{definition.attributes&.size || 0}"
    end
  else
    puts "  ✗ Not found"
  end
  puts
end

# Step 5: Explore Namespace Structure
# ------------------------------------
puts "Step 5: Exploring namespace structure"
puts "-" * 80

loaded_repo.all_namespaces.take(5).each do |ns|
  prefix = loaded_repo.namespace_to_prefix(ns)
  types = loaded_repo.all_type_names(namespace: ns)

  puts "Namespace: #{ns}"
  puts "  Prefix: #{prefix}"
  puts "  Types: #{types.size} (showing first 5)"
  types.take(5).each do |type_name|
    puts "    - #{type_name}"
  end
  puts
end

# Step 6: Batch Type Query
# -------------------------
puts "Step 6: Batch type query"
puts "-" * 80

batch_query = Lutaml::Xsd::BatchTypeQuery.new(loaded_repo)
types_to_query = [
  "urf:UrbanPlanningAreaType",
  "urf:UseDistrictType",
  "urf:ProjectPromotionAreaType",
]

puts "Querying multiple types:"
types_to_query.each { |q| puts "  - #{q}" }
puts

results = batch_query.execute(types_to_query)
results.each do |batch_result|
  if batch_result.resolved
    type_class = batch_result.result.definition.class.name.split("::").last
    puts "  ✓ #{batch_result.query} => Found (#{type_class})"
  else
    puts "  ✗ #{batch_result.query} => Not found"
  end
end
puts

# Step 6: Generate Interactive HTML Documentation
# -----------------------------------------------
puts "Step 6: Generating interactive HTML documentation"
puts "-" * 80

start_time = Time.now

spa_output = File.join(EXAMPLE_DIR, "urban_function_docs.html")
generator = Lutaml::Xsd::Spa::Generator.new(
  loaded_repo.to_package,
  spa_output,
  mode: "inlined",
)
generator.generate

spa_time = Time.now - start_time
spa_size = File.size(spa_output)

puts "✓ SPA generated: #{File.basename(spa_output)}"
puts "  Size: #{(spa_size / 1024.0).round(1)} KB"
puts "  Build time: #{spa_time.round(2)} s"
puts

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "Key concepts demonstrated:"
puts "  ✓ Building packages from complex schemas with imports"
puts "  ✓ Schema location mapping for dependency resolution"
puts "  ✓ Handling large schema sets (100+ types)"
puts "  ✓ Namespace-aware searching"
puts "  ✓ Batch type queries for efficiency"
puts "  ✓ Generating interactive HTML documentation (SPA)"
puts
puts "Output files:"
puts "  - #{OUTPUT_PATH}"
puts "  - #{spa_output}"
puts "=" * 80
