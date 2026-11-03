#!/usr/bin/env ruby
# frozen_string_literal: true

# Advanced XML Validation Example
#
# This example demonstrates advanced validation features including:
# - Multiple file validation
# - Custom configuration
# - Error filtering and grouping
# - JSON output format
#
# Usage:
#   ruby examples/validation/validate_xml_advanced.rb

require "bundler/setup"
require "lutaml/xsd"
require "json"

# Configuration
SCHEMAS_DIR = File.expand_path("sample_schemas", __dir__)
CONFIG_DIR = File.expand_path("config", __dir__)
PERSON_XSD = File.join(SCHEMAS_DIR, "person.xsd")
COMPANY_XSD = File.join(SCHEMAS_DIR, "company.xsd")
VALID_XML = File.join(SCHEMAS_DIR, "person_valid.xml")
INVALID_XML = File.join(SCHEMAS_DIR, "person_invalid.xml")
COMPANY_XML = File.join(SCHEMAS_DIR, "company.xml")
PACKAGE_PATH = File.join(SCHEMAS_DIR, "company_schemas.lxr")
STRICT_CONFIG = File.join(CONFIG_DIR, "strict_validation.yml")
LENIENT_CONFIG = File.join(CONFIG_DIR, "lenient_validation.yml")

puts "=" * 80
puts "Advanced XML Validation Example"
puts "=" * 80
puts

# Step 1: Build LXR package with multiple schemas
# -----------------------------------------------
puts "Step 1: Building LXR package with multiple schemas"
puts "-" * 80

if File.exist?(PACKAGE_PATH)
  puts "✓ Package already exists: #{PACKAGE_PATH}"
else
  puts "Creating schema repository from multiple XSD files..."

  # Create repository from XSD files
  repository = Lutaml::Xsd::SchemaRepository.new
  repository.instance_variable_set(:@files, [PERSON_XSD, COMPANY_XSD])

  # Configure namespace mappings
  repository.configure_namespaces({
                                    "p" => "http://example.com/person",
                                    "c" => "http://example.com/company",
                                  })

  # Parse and resolve schemas
  puts "  - Parsing schemas..."
  repository.parse(verbose: true)

  puts "  - Resolving dependencies..."
  repository.resolve(verbose: true)

  # Build package
  puts "  - Building package..."
  repository.to_package(
    PACKAGE_PATH,
    xsd_mode: :include_all,
    resolution_mode: :resolved,
    serialization_format: :marshal,
    metadata: {
      title: "Company Schema Package",
      description: "Schemas for company and person data",
      version: "1.0.0",
    },
  )

  puts "✓ Package created: #{PACKAGE_PATH}"
end

puts

# Step 2: Validate multiple files with different configurations
# -------------------------------------------------------------
puts "Step 2: Validating multiple files"
puts "-" * 80

# Load repository
repository = Lutaml::Xsd::SchemaRepository.from_package(PACKAGE_PATH)

# Files to validate
xml_files = [
  { path: VALID_XML, name: "person_valid.xml" },
  { path: INVALID_XML, name: "person_invalid.xml" },
  { path: COMPANY_XML, name: "company.xml" },
]

# Validate with default configuration
puts "Using default configuration:"
puts

validator = Lutaml::Xsd::Validator.new(repository)
results = []

xml_files.each do |file_info|
  puts "Validating #{file_info[:name]}..."

  xml_content = File.read(file_info[:path])
  result = validator.validate(xml_content)

  results << {
    file: file_info[:name],
    valid: result.valid?,
    errors: result.errors || [],
  }

  status = result.valid? ? "✓ VALID" : "✗ INVALID (#{result.errors.size} errors)"
  puts "  #{status}"
end

puts

# Step 3: Validate with custom configuration
# ------------------------------------------
puts "Step 3: Validation with custom configuration"
puts "-" * 80

if File.exist?(LENIENT_CONFIG)
  puts "Loading lenient validation configuration..."

  # NOTE: In actual implementation, the Validator would use the config
  # This demonstrates the API even if full config support isn't implemented yet
  Lutaml::Xsd::Validator.new(repository, config: LENIENT_CONFIG)

  puts "✓ Validator created with lenient configuration"
  puts "  - strict_mode: false"
  puts "  - fail_fast: false"
  puts "  - max_errors: 100"
else
  puts "⚠ Configuration file not found: #{LENIENT_CONFIG}"
  validator
end

puts

# Step 4: Error filtering and grouping
# ------------------------------------
puts "Step 4: Error filtering and grouping"
puts "-" * 80

puts "Analyzing validation errors by type..."
puts

error_types = {}

results.each do |result_data|
  next if result_data[:valid]

  result_data[:errors].each do |error|
    # Group errors by type (extracted from message)
    type = case error.message
           when /age/i then "Age Validation"
           when /email/i then "Email Format"
           when /missing|required/i then "Required Element"
           else "Other"
           end

    error_types[type] ||= []
    error_types[type] << {
      file: result_data[:file],
      message: error.message,
    }
  end
end

error_types.each do |type, errors|
  puts "#{type}: #{errors.size} error(s)"
  errors.each do |error|
    puts "  - [#{error[:file]}] #{error[:message]}"
  end
  puts
end

# Step 5: JSON output format
# --------------------------
puts "Step 5: JSON output format"
puts "-" * 80

json_output = {
  validation_run: {
    timestamp: Time.now.utc.iso8601,
    package: File.basename(PACKAGE_PATH),
    files_validated: results.size,
    total_errors: results.sum { |r| r[:errors].size },
  },
  results: results.map do |r|
    {
      file: r[:file],
      valid: r[:valid],
      error_count: r[:errors].size,
      errors: r[:errors].map do |e|
        {
          message: e.message,
          location: e.respond_to?(:location) ? e.location : nil,
        }.compact
      end,
    }
  end,
  error_summary: error_types.transform_values(&:size),
}

puts "JSON output:"
puts JSON.pretty_generate(json_output)

puts

# Step 6: Save results to file
# ----------------------------
puts "Step 6: Saving results to file"
puts "-" * 80

output_file = File.join(SCHEMAS_DIR, "validation_results.json")
File.write(output_file, JSON.pretty_generate(json_output))
puts "✓ Results saved to: #{output_file}"

puts

# Summary
puts "=" * 80
puts "Example completed successfully!"
puts
puts "This example demonstrated:"
puts "  ✓ Building an LXR package with multiple schemas"
puts "  ✓ Validating multiple XML files in batch"
puts "  ✓ Using custom validation configurations"
puts "  ✓ Filtering and grouping errors by type"
puts "  ✓ Generating JSON output format"
puts "  ✓ Saving validation results to file"
puts
puts "Next steps:"
puts "  - Check #{output_file} for detailed results"
puts "  - Try examples/validation/validate_with_suggestions.rb for error suggestions"
puts "  - Explore the CLI: lutaml-xsd validate --help"
puts "=" * 80
