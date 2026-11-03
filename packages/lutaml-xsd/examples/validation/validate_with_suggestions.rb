#!/usr/bin/env ruby
# frozen_string_literal: true

# XML Validation with Error Suggestions Example
#
# This example demonstrates the enhanced error reporting system including:
# - Detailed error messages with context
# - Troubleshooting suggestions
# - Fuzzy matching for type errors
# - Similar type suggestions
#
# Usage:
#   ruby examples/validation/validate_with_suggestions.rb

require "bundler/setup"
require "lutaml/xsd"

# Configuration
SCHEMAS_DIR = File.expand_path("sample_schemas", __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, "person.xsd")
INVALID_XML = File.join(SCHEMAS_DIR, "person_invalid.xml")
PACKAGE_PATH = File.join(SCHEMAS_DIR, "person_schemas.lxr")

puts "=" * 80
puts "XML Validation with Error Suggestions Example"
puts "=" * 80
puts

# Step 1: Setup schema repository
# ------------------------------
puts "Step 1: Setting up schema repository"
puts "-" * 80

if File.exist?(PACKAGE_PATH)
  puts "✓ Using existing package"
else
  puts "Building LXR package..."
  repository = Lutaml::Xsd::SchemaRepository.new
  repository.instance_variable_set(:@files, [PERSON_XSD])
  repository.configure_namespace(prefix: "p", uri: "http://example.com/person")
  repository.parse.resolve
  repository.to_package(
    PACKAGE_PATH,
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    serialization_format: :marshal,
  )
  puts "✓ Package created"
end

repository = Lutaml::Xsd::SchemaRepository.from_package(PACKAGE_PATH)
puts

# Step 2: Demonstrate type suggestions
# ------------------------------------
puts "Step 2: Type resolution with fuzzy matching"
puts "-" * 80

puts "Searching for types (demonstrating suggestion system):"
puts

# Try to find a type with a typo
test_queries = [
  { query: "p:PersonTypo", description: "Typo in type name" },
  { query: "p:AgeTyp", description: "Incomplete type name" },
  { query: "p:EmaillType", description: "Double 'l' typo" },
  { query: "PersonType", description: "Missing namespace prefix" },
]

test_queries.each do |test|
  puts "Query: #{test[:query]} (#{test[:description]})"
  result = repository.find_type(test[:query])

  if result.resolved?
    puts "  ✓ Found: #{result.qname}"
  else
    puts "  ✗ Not found: #{result.error_message}"

    # The error message should include suggestions if available
    # This demonstrates the fuzzy matching capability
    puts "  💡 Suggestions are available in the error message" if result.error_message.include?("Did you mean:")
  end
  puts
end

# Show available types for reference
puts "Available types in the repository:"
all_types = repository.all_type_names(namespace: "http://example.com/person")
all_types.each do |type_name|
  puts "  - #{type_name}"
end

puts

# Step 3: Validate with enhanced errors
# -------------------------------------
puts "Step 3: Validating XML with enhanced error reporting"
puts "-" * 80

puts "Validating: #{File.basename(INVALID_XML)}"
puts

validator = Lutaml::Xsd::Validator.new(repository)
xml_content = File.read(INVALID_XML)
result = validator.validate(xml_content)

if result.valid?
  puts "✓ VALID"
else
  puts "✗ INVALID - Found #{result.errors.size} error(s)"
  puts

  result.errors.each_with_index do |error, idx|
    puts "─" * 80
    puts "Error #{idx + 1} of #{result.errors.size}"
    puts "─" * 80

    if error.respond_to?(:to_detailed_message)
      # Enhanced error with suggestions
      puts error.to_detailed_message
    else
      # Basic error display
      puts "Message: #{error.message}"

      puts "Location: #{error.location}" if error.respond_to?(:location)

      # Show context if available
      if error.respond_to?(:context) && error.context
        puts
        puts "Context:"
        error.context.split("\n").each do |line|
          puts "  #{line}"
        end
      end

      # Show suggestions if available
      if error.respond_to?(:suggestions) && error.suggestions && !error.suggestions.empty?
        puts
        puts "Suggestions:"
        error.suggestions.each do |suggestion|
          puts "  💡 #{suggestion}"
        end
      end

      # Show troubleshooting tips if available
      if error.respond_to?(:troubleshooting) && error.troubleshooting && !error.troubleshooting.empty?
        puts
        puts "Troubleshooting:"
        error.troubleshooting.each do |tip|
          puts "  🔧 #{tip}"
        end
      end
    end

    puts
  end
end

# Step 4: Demonstrate namespace troubleshooting
# ---------------------------------------------
puts "Step 4: Namespace troubleshooting"
puts "-" * 80

puts "Creating XML with namespace issues..."
puts

# Example XML with wrong namespace
wrong_namespace_xml = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <person xmlns="http://example.com/wrong-namespace" id="P003">
    <name>Test Person</name>
    <age>25</age>
    <email>test@example.com</email>
  </person>
XML

puts "Validating XML with incorrect namespace..."
result = validator.validate(wrong_namespace_xml)

if result.valid?
  puts "✓ VALID"
else
  puts "✗ INVALID - Namespace mismatch detected"
  puts

  result.errors.each do |error|
    if error.respond_to?(:to_detailed_message)
      puts error.to_detailed_message
    else
      puts error.message
    end
    puts
  end

  # Show registered namespaces
  puts "Registered namespaces in repository:"
  repository.all_namespaces.each do |ns|
    prefix = repository.namespace_to_prefix(ns)
    puts "  #{prefix || '(default)'} => #{ns}"
  end
end

puts

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "This example demonstrated:"
puts "  ✓ Fuzzy matching for type name typos"
puts "  ✓ Type suggestions when resolution fails"
puts "  ✓ Enhanced error messages with context"
puts "  ✓ Troubleshooting suggestions for common issues"
puts "  ✓ Namespace mismatch detection and guidance"
puts
puts "Key features of the error enhancement system:"
puts "  • Fuzzy matching suggests similar type names"
puts "  • Context shows surrounding XML for better understanding"
puts "  • Suggestions provide actionable fixes"
puts "  • Troubleshooting guides help resolve common issues"
puts
puts "Next steps:"
puts "  - Try examples/lxr_build.rb to learn about package creation"
puts "  - Try examples/lxr_search.rb for type searching capabilities"
puts "=" * 80
