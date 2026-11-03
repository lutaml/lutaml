#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "lutaml/xsd"

puts "=== Automatic Version Detection Example ==="
puts

schemas = {
  "1.0" => "../schemas/valid_xsd_1_0.xsd",
  "1.1" => "../schemas/valid_xsd_1_1_assertions.xsd",
}

schemas.each do |expected_version, relative_path|
  schema_path = File.join(__dir__, relative_path)
  content = File.read(schema_path)

  # Detect version automatically
  detected = Lutaml::Xsd::SchemaValidator.detect_version(content)

  puts "File: #{File.basename(schema_path)}"
  puts "  Expected: XSD #{expected_version}"
  puts "  Detected: XSD #{detected}"
  puts "  Match: #{detected == expected_version ? '✓' : '✗'}"

  # Create validator with detected version
  validator = Lutaml::Xsd::SchemaValidator.new(version: detected)

  begin
    validator.validate(content)
    puts "  Validation: ✓ PASS"
  rescue Lutaml::Xsd::SchemaValidationError => e
    puts "  Validation: ✗ FAIL - #{e.message}"
  end

  puts
end

puts "=== Automatic validation during parse ==="
schemas.each_value do |relative_path|
  schema_path = File.join(__dir__, relative_path)
  content = File.read(schema_path)

  begin
    # Parse with automatic validation (default)
    schema = Lutaml::Xsd.parse(content)
    puts "✓ Successfully parsed #{File.basename(schema_path)}"
    puts "  Target namespace: #{schema.target_namespace}"
  rescue Lutaml::Xsd::SchemaValidationError => e
    puts "✗ Validation failed: #{e.message}"
  end
  puts
end
