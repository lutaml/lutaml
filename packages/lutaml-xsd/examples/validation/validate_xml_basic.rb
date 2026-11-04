#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic XML Validation Example
#
# This example demonstrates basic XML validation using lutaml-xsd.
# It shows how to:
# - Build an LXR package from XSD schemas
# - Load the schema repository
# - Validate XML files
# - Display validation results
#
# Usage:
#   ruby examples/validation/validate_xml_basic.rb

require "bundler/setup"
require "lutaml/xsd"

# Configuration
SCHEMAS_DIR = File.expand_path("sample_schemas", __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, "person.xsd")
VALID_XML = File.join(SCHEMAS_DIR, "person_valid.xml")
INVALID_XML = File.join(SCHEMAS_DIR, "person_invalid.xml")
PACKAGE_PATH = File.join(SCHEMAS_DIR, "person_schemas.lxr")

puts "=" * 80
puts "Basic XML Validation Example"
puts "=" * 80
puts

# Step 1: Build LXR package from XSD schema (if not exists)
# --------------------------------------------------------
puts "Step 1: Building LXR package from XSD schema"
puts "-" * 80

if File.exist?(PACKAGE_PATH)
  puts "✓ Package already exists: #{PACKAGE_PATH}"
else
  puts "Creating schema repository from XSD file..."

  # Create repository from XSD file
  repository = Lutaml::Xsd::SchemaRepository.new
  repository.instance_variable_set(:@files, [PERSON_XSD])

  # Parse and resolve schemas
  puts "  - Parsing schema: #{File.basename(PERSON_XSD)}"
  repository.parse

  puts "  - Resolving dependencies..."
  repository.resolve

  # Build package with resolved schemas
  puts "  - Building package..."
  repository.to_package(
    PACKAGE_PATH,
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    serialization_format: :marshal,
  )

  puts "✓ Package created: #{PACKAGE_PATH}"
end

puts

# Step 2: Load schema repository from LXR package
# -----------------------------------------------
puts "Step 2: Loading schema repository"
puts "-" * 80

puts "Loading schema repository from: #{PACKAGE_PATH}"
repository = Lutaml::Xsd::SchemaRepository.from_package(PACKAGE_PATH)

stats = repository.statistics
puts "✓ Repository loaded:"
puts "  - Total schemas: #{stats[:total_schemas]}"
puts "  - Total types: #{stats[:total_types]}"
puts "  - Namespaces: #{stats[:total_namespaces]}"

puts

# Step 3: Create validator
# ------------------------
puts "Step 3: Creating validator"
puts "-" * 80

validator = Lutaml::Xsd::Validator.new(repository)
puts "✓ Validator initialized"

puts

# Step 4: Validate valid XML file
# ------------------------------
puts "Step 4: Validating valid XML file"
puts "-" * 80

puts "Validating: #{File.basename(VALID_XML)}"
xml_content = File.read(VALID_XML)

result = validator.validate(xml_content)

if result.valid?
  puts "✓ VALID - XML file is valid according to the schema"
else
  puts "✗ INVALID - Found #{result.errors.size} error(s):"
  result.errors.each_with_index do |error, idx|
    puts "  #{idx + 1}. #{error.message}"
    puts "     Location: #{error.location}" if error.respond_to?(:location)
  end
end

puts

# Step 5: Validate invalid XML file
# ---------------------------------
puts "Step 5: Validating invalid XML file"
puts "-" * 80

puts "Validating: #{File.basename(INVALID_XML)}"
xml_content = File.read(INVALID_XML)

result = validator.validate(xml_content)

if result.valid?
  puts "✓ VALID - XML file is valid according to the schema"
else
  puts "✗ INVALID - Found #{result.errors.size} error(s):"
  puts

  # Display detailed error information
  result.errors.each_with_index do |error, idx|
    puts "Error #{idx + 1}:"

    if error.respond_to?(:to_detailed_message)
      # Use enhanced error message if available
      puts error.to_detailed_message.split("\n").map { |line|
        "  #{line}"
      }.join("\n")
    else
      # Basic error display
      puts "  Message: #{error.message}"
      puts "  Location: #{error.location}" if error.respond_to?(:location)

      # Show context if available
      if error.respond_to?(:context) && error.context
        puts "  Context:"
        context_str = error.context.is_a?(String) ? error.context : error.context.inspect
        context_str.split("\n").each do |line|
          puts "    #{line}"
        end
      end
    end

    puts
  end
end

puts

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "This example demonstrated:"
puts "  ✓ Building an LXR package from XSD schemas"
puts "  ✓ Loading a schema repository from an LXR package"
puts "  ✓ Creating a validator instance"
puts "  ✓ Validating XML files against the schema"
puts "  ✓ Displaying validation results with error details"
puts
puts "Next steps:"
puts "  - Try examples/validation/validate_xml_advanced.rb for advanced features"
puts "  - Try examples/validation/validate_with_suggestions.rb for error suggestions"
puts "=" * 80
