#!/usr/bin/env ruby
# frozen_string_literal: true

# Load local development version
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

# Example: Repository Statistics and Analysis
#
# This example demonstrates how to extract and analyze comprehensive
# statistics from a UML repository, including package structure,
# class complexity, relationships, and model quality metrics.

require "lutaml"
require "lutaml/uml_repository/repository"

puts "=" * 80
puts "LUR Repository Statistics Examples"
puts "=" * 80
puts

# Setup: Find a test file
qea_file = Dir.glob("examples/qea/*.qea").first
xmi_file = Dir.glob("examples/qea/*.xmi").first
test_file = qea_file || xmi_file

unless test_file
  puts "No test files found in examples/qea/"
  puts
  puts "This example demonstrates statistics extraction. To run:"
  puts "  1. Place a .qea or .xmi file in examples/qea/"
  puts "  2. Or examine the statistics API below"
  puts
  puts "Statistics API example:"
  puts <<~RUBY
    repo = Lutaml::UmlRepository::Repository.from_xmi("model.xmi")

    stats = repo.statistics

    # Core counts
    puts "Packages: \#{stats[:total_packages]}"
    puts "Classes: \#{stats[:total_classes]}"
    puts "Associations: \#{stats[:total_associations]}"

    # Stereotypes
    stats[:classes_by_stereotype].each do |stereotype, count|
      puts "\#{stereotype}: \#{count}"
    end

    # Complexity metrics
    puts "Max attributes: \#{stats[:max_attributes]}"
    puts "Avg attributes: \#{stats[:avg_attributes]}"

    # Package structure
    puts "Max package depth: \#{stats[:max_package_depth]}"
  RUBY
  exit 0
end

puts "Loading model: #{test_file}"
puts "File size: #{File.size(test_file) / 1024}KB"
puts

# Load repository
if test_file.end_with?(".qea")
  document = Lutaml::Qea.parse(test_file)
  repo = Lutaml::UmlRepository::Repository.new(document: document)
elsif test_file.end_with?(".xmi")
  repo = Lutaml::UmlRepository::Repository.from_xmi(test_file)
end

puts "Repository loaded successfully"
puts

# Statistics Section 1: Overview
puts "=" * 80
puts "1. Model Overview"
puts "=" * 80

stats = repo.statistics

puts "Total elements:"
puts "  Packages:      #{stats[:total_packages]}"
puts "  Classes:       #{stats[:total_classes]}"
puts "  Data types:    #{stats[:total_data_types]}"
puts "  Enumerations:  #{stats[:total_enums]}"
puts "  Associations:  #{stats[:total_associations]}"
puts "  Diagrams:      #{stats[:total_diagrams]}"
puts

# Statistics Section 2: Package Structure
puts "=" * 80
puts "2. Package Structure"
puts "=" * 80

if stats[:max_package_depth]
  puts "Package hierarchy depth: #{stats[:max_package_depth]}"
end

packages = repo.packages_index
if packages.any?
  puts "Total packages: #{packages.size}"
  puts "\nSample packages:"
  packages.first(5).each do |pkg|
    puts "  - #{pkg.name}"
  end
end
puts

# Statistics Section 3: Class Stereotypes
puts "=" * 80
puts "3. Class Stereotypes"
puts "=" * 80

if stats[:classes_by_stereotype]
  stereotype_count = stats[:classes_by_stereotype].size
  puts "Unique stereotypes: #{stereotype_count}"
  puts "\nStereotype distribution:"

  stats[:classes_by_stereotype].sort_by do |_, count|
    -count
  end.first(10).each do |stereotype, count|
    percentage = (count.to_f / stats[:total_classes] * 100).round(1)
    puts "  #{stereotype.ljust(30)} #{count.to_s.rjust(5)} (#{percentage}%)"
  end
else
  puts "No stereotype information available"
end
puts

# Statistics Section 4: Class Complexity
puts "=" * 80
puts "4. Class Complexity Metrics"
puts "=" * 80

all_classes = repo.classes_index.select { |c| c.is_a?(Lutaml::Uml::Class) }

if all_classes.any?
  # Attribute counts
  attr_counts = all_classes.map { |c| c.attributes&.size || 0 }

  puts "Attribute statistics:"
  puts "  Classes with attributes: #{attr_counts.count { |c| c > 0 }}"
  puts "  Min attributes: #{attr_counts.min}"
  puts "  Max attributes: #{attr_counts.max}"
  puts "  Avg attributes: #{(attr_counts.sum.to_f / attr_counts.size).round(2)}"
  puts "  Median attributes: #{attr_counts.sort[attr_counts.size / 2]}"

  # Find most complex classes
  puts "\nMost complex classes (by attribute count):"
  complex_classes = all_classes.map { |c| [c.name, c.attributes&.size || 0] }
                                .sort_by { |_, count| -count }
                                .first(5)

  complex_classes.each do |name, count|
    puts "  #{name}: #{count} attributes"
  end

  # Operation counts
  op_counts = all_classes.map { |c| c.operations&.size || 0 }

  puts "\nOperation statistics:"
  puts "  Classes with operations: #{op_counts.count { |c| c > 0 }}"
  puts "  Max operations: #{op_counts.max}"
  puts "  Avg operations: #{(op_counts.sum.to_f / op_counts.size).round(2)}"
else
  puts "No class data available"
end
puts

# Statistics Section 5: Inheritance
puts "=" * 80
puts "5. Inheritance Analysis"
puts "=" * 80

if all_classes.any?
  classes_with_parent = all_classes.select do |c|
    repo.supertype_of(c)
  end

  puts "Inheritance statistics:"
  puts "  Classes with parent: #{classes_with_parent.size}"
  puts "  Root classes: #{all_classes.size - classes_with_parent.size}"
  puts "  Inheritance usage: " \
       "#{(classes_with_parent.size.to_f / all_classes.size * 100).round(1)}%"

  # Find deepest hierarchies
  max_depth = 0
  deepest_class = nil

  all_classes.first(100).each do |klass|
    ancestors = repo.ancestors_of(klass)
    if ancestors.size > max_depth
      max_depth = ancestors.size
      deepest_class = klass
    end
  end

  if deepest_class
    puts "\nDeepest inheritance hierarchy: #{max_depth} levels"
    puts "  Class: #{deepest_class.name}"
    ancestors = repo.ancestors_of(deepest_class)
    puts "  Ancestors: #{ancestors.map(&:name).join(' < ')}"
  end
end
puts

# Statistics Section 6: Associations
puts "=" * 80
puts "6. Association Analysis"
puts "=" * 80

associations = repo.associations_index

if associations.any?
  puts "Total associations: #{associations.size}"

  # Association types
  assoc_types = associations.group_by do |a|
    a.member_end_type&.first || "unknown"
  end

  puts "\nAssociation types:"
  assoc_types.sort_by { |_, list| -list.size }.first(10).each do |type, list|
    puts "  #{type.ljust(20)} #{list.size}"
  end

  # Most connected classes
  connection_counts = Hash.new(0)

  all_classes.first(100).each do |klass|
    assocs = repo.associations_of(klass)
    connection_counts[klass.name] = assocs.size
  end

  puts "\nMost connected classes:"
  connection_counts.sort_by { |_, count| -count }.first(5).each do |name, count|
    puts "  #{name}: #{count} associations"
  end
end
puts

# Statistics Section 7: Model Quality
puts "=" * 80
puts "7. Model Quality Indicators"
puts "=" * 80

# Run validation
validation = repo.validate

puts "Validation status: #{validation.valid? ? 'PASS ✓' : 'FAIL ✗'}"
puts "  Errors: #{validation.errors.size}"
puts "  Warnings: #{validation.warnings.size}"

if all_classes.any?
  # Calculate documentation coverage
  documented_classes = all_classes.count do |c|
    c.respond_to?(:documentation) && c.documentation && !c.documentation.empty?
  end
  doc_coverage = (documented_classes.to_f / all_classes.size * 100).round(1)

  puts "\nDocumentation coverage:"
  puts "  Documented classes: #{documented_classes}/#{all_classes.size} " \
       "(#{doc_coverage}%)"

  # Naming conventions
  camel_case = all_classes.count { |c| c.name =~ /^[A-Z][a-zA-Z0-9]*$/ }
  naming_compliance = (camel_case.to_f / all_classes.size * 100).round(1)

  puts "\nNaming conventions:"
  puts "  CamelCase classes: #{camel_case}/#{all_classes.size} " \
       "(#{naming_compliance}%)"

  # Abstract classes
  abstract_classes = all_classes.count do |c|
    c.respond_to?(:is_abstract) && c.is_abstract
  end
  abstract_ratio = (abstract_classes.to_f / all_classes.size * 100).round(1)

  puts "\nAbstraction:"
  puts "  Abstract classes: #{abstract_classes}/#{all_classes.size} " \
       "(#{abstract_ratio}%)"
end
puts

# Statistics Section 8: Export Summary
puts "=" * 80
puts "8. Summary Statistics (JSON format)"
puts "=" * 80

require "json"

summary = {
  model: {
    packages: stats[:total_packages],
    classes: stats[:total_classes],
    data_types: stats[:total_data_types],
    enumerations: stats[:total_enums],
    associations: stats[:total_associations],
    diagrams: stats[:total_diagrams]
  },
  structure: {
    max_package_depth: stats[:max_package_depth]
  },
  validation: {
    valid: validation.valid?,
    errors: validation.errors.size,
    warnings: validation.warnings.size
  }
}

if stats[:classes_by_stereotype]
  summary[:stereotypes] = stats[:classes_by_stereotype]
end

puts JSON.pretty_generate(summary)
puts

puts "=" * 80
puts "Statistics analysis complete!"
puts "=" * 80
puts
puts "You can also get statistics via CLI:"
puts "  $ lutaml uml stats model.lur"
puts "  $ lutaml uml stats model.lur --detailed"
puts "  $ lutaml uml stats model.lur --format json"
