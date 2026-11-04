#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "lutaml/xsd"

puts "=== Error Handling Examples ==="
puts

invalid_schemas = {
  "Wrong namespace" => "../schemas/invalid_wrong_namespace.xsd",
  "Wrong root element" => "../schemas/invalid_wrong_root.xsd",
  "Invalid XML syntax" => "../schemas/invalid_syntax.xsd",
}

validator = Lutaml::Xsd::SchemaValidator.new(version: "1.0")

invalid_schemas.each do |description, relative_path|
  schema_path = File.join(__dir__, relative_path)

  puts "Testing: #{description}"
  puts "  File: #{File.basename(schema_path)}"

  begin
    content = File.read(schema_path)
    validator.validate(content)
    puts "  Result: ✗ UNEXPECTED - Schema should have failed validation"
  rescue Lutaml::Xsd::SchemaValidationError => e
    puts "  Result: ✓ EXPECTED ERROR"
    puts "  Error: #{e.message}"
  rescue StandardError => e
    puts "  Result: ✗ UNEXPECTED ERROR TYPE"
    puts "  Error: #{e.class} - #{e.message}"
  end

  puts
end

puts "=== Testing XSD 1.1 features in 1.0 mode ==="
xsd_1_1_path = File.join(__dir__, "../schemas/valid_xsd_1_1_assertions.xsd")
xsd_1_1_content = File.read(xsd_1_1_path)

puts "Validating XSD 1.1 schema with XSD 1.0 validator:"
validator_1_0 = Lutaml::Xsd::SchemaValidator.new(version: "1.0")

begin
  validator_1_0.validate(xsd_1_1_content)
  puts "  Result: ✗ UNEXPECTED - Should reject XSD 1.1 features"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "  Result: ✓ EXPECTED ERROR"
  puts "  Error: #{e.message}"
end

puts
puts "Validating same schema with XSD 1.1 validator:"
validator_1_1 = Lutaml::Xsd::SchemaValidator.new(version: "1.1")

begin
  validator_1_1.validate(xsd_1_1_content)
  puts "  Result: ✓ SUCCESS"
rescue Lutaml::Xsd::SchemaValidationError => e
  puts "  Result: ✗ UNEXPECTED ERROR"
  puts "  Error: #{e.message}"
end
