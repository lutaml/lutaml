#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Get statistics from LER package
# This script demonstrates retrieving comprehensive statistics from a package

require_relative "../lib/expressir"

PACKAGE_FILE = File.expand_path("ler/simple_example.ler", __dir__)

unless File.exist?(PACKAGE_FILE)
  puts "Error: Package not found: #{PACKAGE_FILE}"
  puts "Run 'ruby examples/ler_build.rb' first to create the package."
  exit 1
end

puts "LER Package Statistics Example"
puts "=" * 60
puts "Package: #{File.basename(PACKAGE_FILE)}"
puts

# Load package
repo = Expressir::Model::Repository.from_package(PACKAGE_FILE)

# Get statistics
stats = repo.statistics

puts "Overall Statistics"
puts "-" * 60
puts "Total schemas:    #{stats[:total_schemas]}"
puts "Total entities:   #{stats[:total_entities]}"
puts "Total types:      #{stats[:total_types]}"
puts "Total functions:  #{stats[:total_functions]}"
puts "Total rules:      #{stats[:total_rules]}"
puts "Total procedures: #{stats[:total_procedures]}"
puts

puts "Entities by Schema"
puts "-" * 60
stats[:entities_by_schema].each do |schema, count|
  puts "  #{schema}: #{count}"
end
puts

puts "Types by Category"
puts "-" * 60
stats[:types_by_category].each do |category, count|
  puts "  #{category}: #{count}"
end
puts

puts "Interface Relationships"
puts "-" * 60
puts "  USE FROM:       #{stats[:interfaces][:use_from]}"
puts "  REFERENCE FROM: #{stats[:interfaces][:reference_from]}"
puts

# Validate repository
puts "Validation"
puts "-" * 60
validation = repo.validate
if validation[:valid?]
  puts "  ✓ Repository is valid"
else
  puts "  ✗ Validation failed"
  puts "  Errors: #{validation[:errors].size}"
  validation[:errors].first(3).each do |error|
    puts "    - #{error[:message]}"
  end
end

if validation[:warnings]&.any?
  puts "  Warnings: #{validation[:warnings].size}"
  validation[:warnings].first(3).each do |warning|
    puts "    - #{warning[:message]}"
  end
end

puts "\n#{'=' * 60}"
puts "Statistics retrieved successfully!"
puts
