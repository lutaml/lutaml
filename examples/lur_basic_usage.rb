#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Basic LUR Repository Operations
#
# This example demonstrates basic repository operations including:
# - Loading from XMI or LUR files
# - Finding packages and classes
# - Navigating inheritance hierarchies
# - Querying associations

# Load local development version
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "lutaml"
require "lutaml/uml_repository/repository"

# Example 1: Load from XMI file
puts "=" * 80
puts "Example 1: Load from XMI"
puts "=" * 80

# Build repository from XMI (slow, 5-8 seconds for large models)
# repo = Lutaml::UmlRepository::Repository.from_xmi("model.xmi")

# Or use smart file detection (auto-detects .xmi or .lur)
# repo = Lutaml::UmlRepository::Repository.from_file("model.xmi")

# For this example, we'll show the API without actual file
puts "repo = Lutaml::UmlRepository::Repository.from_xmi('model.xmi')"
puts "# Builds indexes from XMI (5-8s for large models)"
puts

# Example 2: Load from LUR package (fast loading)
puts "=" * 80
puts "Example 2: Load from LUR package (< 100ms)"
puts "=" * 80

puts "repo = Lutaml::UmlRepository::Repository.from_package('model.lur')"
puts "# Fast loading from pre-indexed package"
puts

# Example 3: Smart caching
puts "=" * 80
puts "Example 3: Smart caching"
puts "=" * 80

puts "repo = Lutaml::UmlRepository::Repository.from_file_cached('model.xmi')"
puts "# Uses cached .lur if newer than .xmi, otherwise rebuilds"
puts

# For demonstration, let's use a QEA file if available
qea_file = Dir.glob("examples/qea/*.qea").first
if qea_file
  puts "=" * 80
  puts "Example 4: Loading from QEA file (10-20x faster than XMI)"
  puts "=" * 80
  puts "QEA file found: #{qea_file}"

  # Parse QEA directly
  document = Lutaml::Qea.parse(qea_file)
  repo = Lutaml::UmlRepository::Repository.new(document: document)

  puts "Loaded successfully!"
  puts

  # Example 5: Finding packages
  puts "=" * 80
  puts "Example 5: Finding packages"
  puts "=" * 80

  # Find root package
  root = repo.find_package("ModelRoot")
  if root
    puts "Root package: #{root.name}"
    puts "Root type: #{root.class}"
  end
  puts

  # List top-level packages
  packages = repo.list_packages("ModelRoot", recursive: false)
  puts "Top-level packages (#{packages.size}):"
  packages.first(5).each do |pkg|
    puts "  - #{pkg.name}"
  end
  puts "  ..." if packages.size > 5
  puts

  # Example 6: Finding classes
  puts "=" * 80
  puts "Example 6: Finding classes"
  puts "=" * 80

  # Get all classes
  all_classes = repo.classes_index
  puts "Total classes: #{all_classes.size}"
  puts

  # Find by stereotype
  if all_classes.any?
    first_class = all_classes.first
    puts "First class: #{first_class.name}"
    if first_class.respond_to?(:stereotype) && first_class.stereotype
      puts "  Stereotype: #{first_class.stereotype}"
    end
  end
  puts

  # Example 7: Working with associations
  puts "=" * 80
  puts "Example 7: Associations"
  puts "=" * 80

  associations = repo.associations_index
  puts "Total associations: #{associations.size}"

  if associations.any?
    assoc = associations.first
    puts "\nFirst association:"
    member_end = assoc.member_end
    if member_end.is_a?(Array) && member_end.any?
      puts "  Name: #{member_end.first&.name || 'unnamed'}"
    elsif member_end.respond_to?(:name)
      puts "  Name: #{member_end.name}"
    else
      puts "  Name: unnamed"
    end

    member_end_type = assoc.member_end_type
    if member_end_type.is_a?(Array) && member_end_type.any?
      puts "  Type: #{member_end_type.first}"
    elsif member_end_type
      puts "  Type: #{member_end_type}"
    end
  end
  puts

  # Example 8: Statistics
  puts "=" * 80
  puts "Example 8: Repository statistics"
  puts "=" * 80

  stats = repo.statistics
  puts "Packages: #{stats[:total_packages]}"
  puts "Classes: #{stats[:total_classes]}"
  puts "Associations: #{stats[:total_associations]}"
  puts "Diagrams: #{stats[:total_diagrams]}"

  if stats[:classes_by_stereotype]
    puts "\nClasses by stereotype:"
    stats[:classes_by_stereotype].first(5).each do |stereotype, count|
      puts "  #{stereotype}: #{count}"
    end
  end
  puts

  # Example 9: Search
  puts "=" * 80
  puts "Example 9: Search"
  puts "=" * 80

  # Search for elements
  results = repo.search("Object", types: [:class])
  puts "Search for 'Object' in class names:"
  puts "  Found #{results[:total]} matches"
  if results[:classes]
    puts "  Classes (#{results[:classes].size}):"
    results[:classes].first(3).each do |result|
      puts "    - #{result.element.name}"
    end
  end
  puts

else
  puts "=" * 80
  puts "No QEA files found in examples/qea/"
  puts "=" * 80
  puts
  puts "To use this example:"
  puts "1. Place a .qea or .xmi file in examples/qea/"
  puts "2. Or modify the script to point to your model file"
  puts
  puts "Example API usage (without actual file):"
  puts <<~RUBY

    # Load repository
    repo = Lutaml::UmlRepository::Repository.from_xmi("model.xmi")

    # Find package
    package = repo.find_package("ModelRoot::MyPackage")

    # Find class
    klass = repo.find_class("ModelRoot::MyPackage::MyClass")

    # Get class attributes
    klass.attributes.each do |attr|
      puts "\#{attr.name}: \#{attr.type}"
    end

    # Find by stereotype
    feature_types = repo.find_classes_by_stereotype("featureType")

    # Get inheritance
    parent = repo.supertype_of(klass)
    children = repo.subtypes_of(klass)

    # Get associations
    assocs = repo.associations_of(klass)

    # Search
    results = repo.search("Building")

    # Get statistics
    stats = repo.statistics
    puts "Total classes: \#{stats[:total_classes]}"
  RUBY
end

puts "=" * 80
puts "Example complete!"
puts "=" * 80