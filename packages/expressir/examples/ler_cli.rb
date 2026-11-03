#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Using LER via CLI commands
# This script demonstrates CLI usage for package operations

PACKAGE_FILE = File.expand_path("ler/simple_example.ler", __dir__)

unless File.exist?(PACKAGE_FILE)
  puts "Error: Package not found: #{PACKAGE_FILE}"
  puts "Run 'ruby examples/ler_build.rb' first to create the package."
  exit 1
end

puts "LER CLI Commands Example"
puts "=" * 60
puts

# Example 1: Package info
puts "Example 1: Display package information"
puts "-" * 60
puts "Command: expressir package info #{PACKAGE_FILE}"
puts
system("bundle exec expressir package info #{PACKAGE_FILE}")
puts

# Example 2: Find entity
puts "\nExample 2: Find specific entity"
puts "-" * 60
puts "Command: expressir entity find \"simple_example.product\" --from #{PACKAGE_FILE}"
puts
system("bundle exec expressir entity find \"simple_example.product\" --from #{PACKAGE_FILE}")
puts

# Example 3: List entities
puts "\nExample 3: List all entities"
puts "-" * 60
puts "Command: expressir entity list --from #{PACKAGE_FILE}"
puts
system("bundle exec expressir entity list --from #{PACKAGE_FILE}")
puts

# Example 4: Find type
puts "\nExample 4: Find specific type"
puts "-" * 60
puts "Command: expressir type find \"simple_example.product_status\" --from #{PACKAGE_FILE}"
puts
system("bundle exec expressir type find \"simple_example.product_status\" --from #{PACKAGE_FILE}")
puts

# Example 5: List types by category
puts "\nExample 5: List types by category"
puts "-" * 60
puts "Command: expressir type list --from #{PACKAGE_FILE} --category enumeration"
puts
system("bundle exec expressir type list --from #{PACKAGE_FILE} --category enumeration")
puts

# Example 6: Show statistics
puts "\nExample 6: Show statistics"
puts "-" * 60
puts "Command: expressir stats show #{PACKAGE_FILE}"
puts
system("bundle exec expressir stats show #{PACKAGE_FILE}")
puts

puts "=" * 60
puts "CLI examples complete!"
puts
puts "All commands available:"
puts "  expressir package build ROOT_SCHEMA OUTPUT [options]"
puts "  expressir package info PACKAGE [options]"
puts "  expressir package validate PACKAGE [options]"
puts "  expressir entity find QUALIFIED_NAME --from PACKAGE"
puts "  expressir entity list --from PACKAGE [--schema NAME]"
puts "  expressir type find QUALIFIED_NAME --from PACKAGE"
puts "  expressir type list --from PACKAGE [--category TYPE]"
puts "  expressir stats show PACKAGE [--format FORMAT]"
puts
