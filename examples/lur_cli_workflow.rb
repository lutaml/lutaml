#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: CLI Workflow Patterns
#
# This example demonstrates common command-line workflow patterns for
# working with LUR packages, including building, validation, and export.

# Load local development version
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "lutaml"
require "lutaml/uml_repository/repository"
require "fileutils"

puts "=" * 80
puts "LUR CLI Workflow Examples"
puts "=" * 80
puts

# Setup: Find a test file
qea_file = Dir.glob("examples/qea/*.qea").first
xmi_file = Dir.glob("examples/qea/*.xmi").first
test_file = qea_file || xmi_file

unless test_file
  puts "No test files found in examples/qea/"
  puts
  puts "This example demonstrates CLI workflows. To run:"
  puts "  1. Place a .qea or .xmi file in examples/qea/"
  puts "  2. Or use the CLI commands directly:"
  puts
  puts "CLI command examples:"
  puts <<~TEXT
    # Build LUR package from XMI
    $ lutaml uml build model.xmi -o model.lur

    # Build from QEA (10-20x faster)
    $ lutaml uml build model.qea -o model.lur

    # Show package info
    $ lutaml uml info model.lur

    # List packages
    $ lutaml uml ls model.lur

    # Show package tree
    $ lutaml uml tree model.lur --depth 3

    # Search
    $ lutaml uml search model.lur "Building"

    # Find by stereotype
    $ lutaml uml find model.lur --stereotype featureType

    # Get statistics
    $ lutaml uml stats model.lur

    # Validate
    $ lutaml uml validate model.lur

    # Export to CSV
    $ lutaml uml export model.lur --format csv -o classes.csv

    # Generate documentation site
    $ lutaml uml docs model.lur -o docs/

    # Start interactive shell
    $ lutaml uml repl model.lur

    # Watch mode (auto-rebuild on changes)
    $ lutaml uml watch model.xmi -o model.lur
  TEXT
  exit 0
end

puts "Test file found: #{test_file}"
puts "File size: #{File.size(test_file) / 1024}KB"
puts

# Workflow 1: Build LUR package
puts "=" * 80
puts "Workflow 1: Building LUR package"
puts "=" * 80

lur_output = "examples/workflow_test.lur"
FileUtils.rm_f(lur_output)

puts "Loading from: #{test_file}"
start_time = Time.now

# Parse the source file
if test_file.end_with?(".qea")
  puts "Parsing QEA file (fast)..."
  document = Lutaml::Qea.parse(test_file)
elsif test_file.end_with?(".xmi")
  puts "Parsing XMI file..."
  document = Lutaml::Parser.parse([File.new(test_file)]).first
else
  puts "Unknown file type"
  exit 1
end

parse_time = Time.now - start_time
puts "Parsed in #{parse_time.round(2)}s"

# Build repository
puts "Building repository..."
repo = Lutaml::UmlRepository::Repository.new(document: document)
build_time = Time.now - start_time - parse_time
puts "Built in #{build_time.round(2)}s"

# Export to LUR package
puts "Exporting to LUR package..."
export_start = Time.now
repo.export_to_package(lur_output,
                       name: "Test Model",
                       version: "1.0",
                       serialization_format: :marshal)
export_time = Time.now - export_start
puts "Exported in #{export_time.round(2)}s"
puts "Package created: #{lur_output} (#{File.size(lur_output) / 1024}KB)"
puts

# Workflow 2: Load from LUR (fast)
puts "=" * 80
puts "Workflow 2: Fast loading from LUR"
puts "=" * 80

load_start = Time.now
loaded_repo = Lutaml::UmlRepository::Repository.from_package(lur_output)
load_time = Time.now - load_start
puts "Loaded in #{load_time.round(2)}s (vs #{parse_time.round(2)}s for parsing)"
puts "Speedup: #{(parse_time / load_time).round(1)}x faster"
puts

# Workflow 3: Validation
puts "=" * 80
puts "Workflow 3: Model validation"
puts "=" * 80

result = loaded_repo.validate
puts "Validation result: #{result.valid? ? 'VALID ✓' : 'INVALID ✗'}"
puts "Errors: #{result.errors.size}"
puts "Warnings: #{result.warnings.size}"

if result.errors.any?
  puts "\nFirst 3 errors:"
  result.errors.first(3).each do |error|
    puts "  - #{error}"
  end
end

if result.warnings.any?
  puts "\nFirst 3 warnings:"
  result.warnings.first(3).each do |warning|
    puts "  - #{warning}"
  end
end
puts

# Workflow 4: Statistics
puts "=" * 80
puts "Workflow 4: Model statistics"
puts "=" * 80

stats = loaded_repo.statistics
puts "Model overview:"
puts "  Packages: #{stats[:total_packages]}"
puts "  Classes: #{stats[:total_classes]}"
puts "  Data types: #{stats[:total_data_types]}"
puts "  Enumerations: #{stats[:total_enums]}"
puts "  Associations: #{stats[:total_associations]}"
puts "  Diagrams: #{stats[:total_diagrams]}"

if stats[:max_package_depth]
  puts "\nPackage structure:"
  puts "  Max depth: #{stats[:max_package_depth]}"
end

if stats[:classes_by_stereotype]
  puts "\nTop stereotypes:"
  stats[:classes_by_stereotype].first(5).each do |stereotype, count|
    puts "  #{stereotype}: #{count}"
  end
end
puts

# Workflow 5: Query and export
puts "=" * 80
puts "Workflow 5: Query and export"
puts "=" * 80

# Find all classes
all_classes = loaded_repo.classes_index
puts "Found #{all_classes.size} classes"

if all_classes.any?
  # Sample some classes
  sample_classes = all_classes.first(5)
  puts "\nSample classes:"
  sample_classes.each do |klass|
    puts "  - #{klass.name}"
    if klass.respond_to?(:stereotype) && klass.stereotype
      puts "    Stereotype: #{klass.stereotype}"
    end
    if klass.respond_to?(:attributes) && klass.attributes
      puts "    Attributes: #{klass.attributes.size}"
    end
  end

  # Search example
  puts "\nSearch for 'Object':"
  results = loaded_repo.search("Object", types: [:class])
  puts "  Found #{results[:total]} matches in class names"
end
puts

# Workflow 6: Smart caching demonstration
puts "=" * 80
puts "Workflow 6: Smart caching"
puts "=" * 80

puts "Smart caching automatically uses LUR if newer than source:"
puts
puts "# First run - builds from source"
puts "repo = Repository.from_file_cached('#{test_file}')"
puts "# Creates #{test_file.sub(/\.(xmi|qea)$/, '.lur')}"
puts
puts "# Subsequent runs - loads from cache"
puts "repo = Repository.from_file_cached('#{test_file}')"
puts "# Uses cached .lur (< 100ms)"
puts

# Cleanup
puts "=" * 80
puts "Cleanup"
puts "=" * 80
FileUtils.rm_f(lur_output)
puts "Removed test file: #{lur_output}"
puts

puts "=" * 80
puts "Workflow examples complete!"
puts "=" * 80
puts
puts "Summary of CLI commands:"
puts "  build      - Build LUR package from XMI/QEA"
puts "  info       - Show package metadata"
puts "  validate   - Validate model integrity"
puts "  ls         - List elements"
puts "  tree       - Show package hierarchy"
puts "  inspect    - Show element details"
puts "  search     - Full-text search"
puts "  find       - Find by criteria"
puts "  stats      - Model statistics"
puts "  export     - Export to various formats"
puts "  docs       - Generate documentation site"
puts "  serve      - Start web UI"
puts "  repl       - Interactive shell"
puts
puts "Run 'lutaml uml --help' for full command reference"
