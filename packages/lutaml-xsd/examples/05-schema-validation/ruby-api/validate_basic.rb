#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "lutaml/xsd"

puts "=== Basic Schema Validation Example ==="
puts

# Read a valid XSD 1.0 schema
schema_path = File.join(__dir__, "../schemas/valid_xsd_1_0.xsd")
schema_content = File.read(schema_path)

# Create a validator for XSD 1.0
validator = Lutaml::Xsd::SchemaValidator.new(version: "1.0")

# Validate the schema
puts "Validating: #{schema_path}"
begin
  validator.validate(schema_content)
  puts "✓ Schema is valid (XSD 1.0)"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "✗ Validation failed: #{e.message}"
  exit 1
end

puts
puts "=== Parsing validated schema ==="
schema = Lutaml::Xsd.parse(schema_content)
puts "Target namespace: #{schema.target_namespace}"
puts "Elements: #{schema.element.map(&:name).join(', ')}"
puts "Complex types: #{schema.complex_type.map(&:name).join(', ')}"
