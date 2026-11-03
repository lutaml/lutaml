#!/usr/bin/env ruby
# frozen_string_literal: true

# This example demonstrates schema validation using the Ruby API

require "lutaml/xsd"

# Example 1: Validating a valid XSD 1.0 schema
puts "=" * 70
puts "Example 1: Validating a valid XSD 1.0 schema"
puts "=" * 70

valid_schema = File.read("../schemas/valid_schema.xsd")

begin
  validator = Lutaml::Xsd::SchemaValidator.new(version: "1.0")
  validator.validate(valid_schema)
  puts "✓ Schema is valid (XSD 1.0)"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "✗ Validation failed: #{e.message}"
end

# Example 2: Validating an XSD 1.1 schema
puts "\n#{'=' * 70}"
puts "Example 2: Validating an XSD 1.1 schema"
puts "=" * 70

xsd11_schema = File.read("../schemas/xsd11_schema.xsd")

# Try with XSD 1.0 validator (should fail)
puts "\nWith XSD 1.0 validator:"
begin
  validator_1_0 = Lutaml::Xsd::SchemaValidator.new(version: "1.0")
  validator_1_0.validate(xsd11_schema)
  puts "✓ Schema is valid"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "✗ Validation failed: #{e.message}"
end

# Try with XSD 1.1 validator (should succeed)
puts "\nWith XSD 1.1 validator:"
begin
  validator_1_1 = Lutaml::Xsd::SchemaValidator.new(version: "1.1")
  validator_1_1.validate(xsd11_schema)
  puts "✓ Schema is valid (XSD 1.1)"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "✗ Validation failed: #{e.message}"
end

# Example 3: Automatic version detection
puts "\n#{'=' * 70}"
puts "Example 3: Automatic version detection"
puts "=" * 70

schemas = {
  "valid_schema.xsd" => valid_schema,
  "xsd11_schema.xsd" => xsd11_schema,
}

schemas.each do |filename, content|
  detected_version = Lutaml::Xsd::SchemaValidator.detect_version(content)
  puts "\n#{filename}:"
  puts "  Detected version: XSD #{detected_version}"

  validator = Lutaml::Xsd::SchemaValidator.new(version: detected_version)
  begin
    validator.validate(content)
    puts "  ✓ Validation passed"
  rescue Lutaml::Xsd::SchemaValidationError => e
    puts "  ✗ Validation failed: #{e.message}"
  end
end

# Example 4: Validating invalid schemas
puts "\n#{'=' * 70}"
puts "Example 4: Validating invalid schemas"
puts "=" * 70

invalid_schemas = [
  "../schemas/invalid_wrong_namespace.xsd",
  "../schemas/invalid_no_namespace.xsd",
  "../schemas/invalid_non_schema.xsd",
]

validator = Lutaml::Xsd::SchemaValidator.new

invalid_schemas.each do |schema_file|
  puts "\n#{File.basename(schema_file)}:"
  begin
    content = File.read(schema_file)
    validator.validate(content)
    puts "  ✓ Schema is valid (unexpected!)"
  rescue Lutaml::Xsd::SchemaValidationError => e
    puts "  ✗ Validation failed (expected): #{e.message}"
  end
end

# Example 5: Integration with Lutaml::Xsd.parse
puts "\n#{'=' * 70}"
puts "Example 5: Integration with Lutaml::Xsd.parse"
puts "=" * 70

puts "\nAutomatic validation (default):"
begin
  schema = Lutaml::Xsd.parse(valid_schema)
  puts "✓ Schema parsed successfully"
  puts "  Target namespace: #{schema.target_namespace}"
  puts "  Elements: #{schema.element.size}"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "✗ Validation failed: #{e.message}"
end

puts "\nDisabling validation:"
begin
  Lutaml::Xsd.parse(valid_schema, validate_schema: false)
  puts "✓ Schema parsed (validation skipped)"
rescue StandardError => e
  puts "✗ Parsing failed: #{e.message}"
end

# Example 6: Batch validation workflow
puts "\n#{'=' * 70}"
puts "Example 6: Batch validation workflow"
puts "=" * 70

schema_dir = "../schemas"
schema_files = Dir.glob("#{schema_dir}/*.xsd")

results = {
  valid: [],
  invalid: [],
}

schema_files.each do |file|
  filename = File.basename(file)
  content = File.read(file)

  # Detect version
  version = Lutaml::Xsd::SchemaValidator.detect_version(content)
  validator = Lutaml::Xsd::SchemaValidator.new(version: version)

  begin
    validator.validate(content)
    results[:valid] << { file: filename, version: version }
  rescue Lutaml::Xsd::SchemaValidationError => e
    results[:invalid] << { file: filename, error: e.message }
  end
end

puts "\nValidation Summary:"
puts "\nValid schemas (#{results[:valid].size}):"
results[:valid].each do |r|
  puts "  ✓ #{r[:file]} (XSD #{r[:version]})"
end

puts "\nInvalid schemas (#{results[:invalid].size}):"
results[:invalid].each do |r|
  puts "  ✗ #{r[:file]}"
  puts "    Error: #{r[:error]}"
end

puts "\n#{'=' * 70}"
puts "Examples completed!"
puts "=" * 70
