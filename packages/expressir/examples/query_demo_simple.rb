#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple LER Query Demonstration
# Demonstrates querying capabilities on existing LER package

require_relative "../lib/expressir"

PACKAGE_FILE = "examples/ler/simple_example.ler"

puts "======================================================================"
puts "             LER Query Demonstration                                 "
puts "======================================================================"
puts

unless File.exist?(PACKAGE_FILE)
  puts "Creating package first..."
  system("bundle exec expressir package build examples/ler/simple_schema.exp #{PACKAGE_FILE} --name 'Demo' --version '1.0.0'",
         out: File::NULL, err: File::NULL)
end

unless File.exist?(PACKAGE_FILE)
  puts "Error: Package not found. Please run:"
  puts "  bundle exec expressir package build examples/ler/simple_schema.exp #{PACKAGE_FILE}"
  exit 1
end

puts "Loading package: #{PACKAGE_FILE}"
repo = Expressir::Package::Reader.load(PACKAGE_FILE)
search = Expressir::Model::SearchEngine.new(repo)
puts "✓ Loaded successfully"
puts

# Demo 1: Basic Statistics
puts "Demo 1: Basic Repository Statistics"
puts "----------------------------------------------------------------------"
stats = repo.statistics
puts "Schemas: #{stats[:total_schemas]}"
puts "Entities: #{stats[:total_entities]}"
puts "Types: #{stats[:total_types]}"
puts

# Demo 2: List Elements
puts "Demo 2: List All Entities"
puts "----------------------------------------------------------------------"
entities = search.list(type: "entity")
entities.each { |e| puts "  - #{e[:id]} (#{e[:schema]})" }
puts

# Demo 3: Search with Patterns
puts "Demo 3: Search with Wildcard Pattern"
puts "----------------------------------------------------------------------"
results = search.search(pattern: "product*")
puts "Found #{results.size} results for 'product*':"
results.each { |r| puts "  - #{r[:path]}" }
puts

# Demo 4: Advanced Search - Depth Filtering (Phase 3)
puts "Demo 4: Depth-Filtered Search (Phase 3 Feature)"
puts "----------------------------------------------------------------------"
results = search.search_with_depth(pattern: "product", max_depth: 2)
puts "Results at depth ≤ 2:"
results.each do |r|
  depth = r[:path]&.split(".")&.size || 0
  puts "  - #{r[:path]} (depth: #{depth})"
end
puts

# Demo 5: Advanced Search - Relevance Ranking (Phase 3)
puts "Demo 5: Relevance-Ranked Search (Phase 3 Feature)"
puts "----------------------------------------------------------------------"
results = search.search_ranked(pattern: "product")
puts "Results ranked by relevance:"
results.each do |r|
  puts "  - #{r[:path]} (score: #{r[:relevance_score]})"
end
puts

# Demo 6: Advanced Search - Combined (Phase 3)
puts "Demo 6: Advanced Combined Search (Phase 3 Feature)"
puts "----------------------------------------------------------------------"
results = search.search_advanced(pattern: "product", max_depth: 2, ranked: true)
puts "Depth-filtered + ranked results:"
results.each do |r|
  puts "  - #{r[:path]} (score: #{r[:relevance_score]})"
end
puts

# Demo 7: Schema Categorization (Phase 3)
puts "Demo 7: Schema Categorization (Phase 3 Feature)"
puts "----------------------------------------------------------------------"
categories = repo.schemas_by_category
categories.each do |category, schemas|
  next if schemas.empty?

  puts "#{category}: #{schemas.size} schema(s)"
  schemas.each { |s| puts "  - #{s.id}" }
end
puts

# Demo 8: Schema Complexity Analysis (Phase 3)
puts "Demo 8: Schema Complexity Analysis (Phase 3 Feature)"
puts "----------------------------------------------------------------------"
complex = repo.schemas_by_complexity(5)
complex.each do |item|
  puts "  - #{item[:schema].id}: complexity #{item[:complexity]}"
end
puts

# Demo 9: Package Validation (Phase 2)
puts "Demo 9: Enhanced Package Validation (Phase 2 Feature)"
puts "----------------------------------------------------------------------"
validation = repo.validate(strict: true, check_completeness: true)
puts "Valid: #{validation[:valid?]}"
puts "Errors: #{validation[:errors]&.size || 0}"
puts "Warnings: #{validation[:warnings]&.size || 0}"
puts

puts "======================================================================"
puts "  All Demos Complete! ✓"
puts "======================================================================"
puts
puts "Phase 2 & 3 Features Demonstrated:"
puts "  ✓ Enhanced validation with multiple options"
puts "  ✓ Depth-filtered search"
puts "  ✓ Relevance-ranked search"
puts "  ✓ Combined advanced search"
puts "  ✓ Schema categorization"
puts "  ✓ Complexity analysis"
puts "  ✓ Dependency statistics"
puts
