#!/usr/bin/env ruby
# frozen_string_literal: true

# Complete LER Demonstration
# Shows package creation, searching, and querying with all advanced features

require_relative "../lib/expressir"

class LERDemo
  SCHEMA_FILE = File.expand_path("ler/simple_schema.exp", __dir__)
  PACKAGE_FILE = File.expand_path("ler/simple_example.ler", __dir__)

  def run
    print_header("LER Package Creation and Query Demonstration")

    create_package
    load_and_query_package
    demonstrate_advanced_search
    demonstrate_statistics
    demonstrate_validation

    print_header("Demo Complete!", "=")
    puts "\nPackage saved at: #{PACKAGE_FILE}"
    puts "You can now use CLI commands like:"
    puts "  expressir package info #{PACKAGE_FILE}"
    puts "  expressir package search #{PACKAGE_FILE} 'product'"
    puts "  expressir package tree #{PACKAGE_FILE}"
  end

  private

  def create_package
    print_section("Step 1: Creating LER Package")

    unless File.exist?(SCHEMA_FILE)
      puts "Error: Schema file not found: #{SCHEMA_FILE}"
      exit 1
    end

    # Use CLI to build package (recommended approach)
    puts "Building LER package from: #{File.basename(SCHEMA_FILE)}"
    puts "Output: #{File.basename(PACKAGE_FILE)}"

    cmd = "bundle exec expressir package build #{SCHEMA_FILE} #{PACKAGE_FILE} " \
          "--name 'Simple Product Management Schema' " \
          "--version '1.0.0' " \
          "--description 'Demonstrates LER features with product entities' " \
          "--express-mode include_all " \
          "--resolution-mode resolved " \
          "--serialization-format yaml"

    system(cmd, out: File::NULL, err: File::NULL)

    unless File.exist?(PACKAGE_FILE)
      puts "Error: Failed to create package"
      exit 1
    end

    file_size = File.size(PACKAGE_FILE)
    puts "  ✓ Package created: #{(file_size / 1024.0).round(2)} KB"
  end

  def load_and_query_package
    print_section("Step 2: Loading and Basic Queries")

    # Load package (force class load first)
    puts "Loading package from: #{File.basename(PACKAGE_FILE)}"
    require_relative "../lib/expressir/model/repository"
    require_relative "../lib/expressir/package/reader"
    @repo = Expressir::Package::Reader.load(PACKAGE_FILE)
    require_relative "../lib/expressir/model/search_engine"
    @search = Expressir::Model::SearchEngine.new(@repo)
    puts "  ✓ Package loaded"

    # Basic statistics
    stats = @repo.statistics
    puts "\nPackage contains:"
    puts "  Schemas: #{stats[:total_schemas]}"
    puts "  Entities: #{stats[:total_entities]}"
    puts "  Types: #{stats[:total_types]}"

    # List entities
    puts "\nEntities:"
    entities = @search.list(type: "entity")
    entities.each do |e|
      puts "  - #{e[:id]} (#{e[:schema]})"
    end

    # List types by category
    puts "\nTypes by category:"
    stats[:types_by_category].each do |category, count|
      next if count.zero?

      puts "  #{category}: #{count}"
      types = @search.list(type: "type", category: category.to_s)
      types.each do |t|
        puts "    - #{t[:id]}"
      end
    end
  end

  def demonstrate_advanced_search
    print_section("Step 3: Advanced Search Features (Phase 3)")

    # Pattern matching
    puts "1. Wildcard pattern search:"
    results = @search.search(pattern: "product*", type: "entity")
    puts "  Found #{results.size} entities starting with 'product':"
    results.each { |r| puts "    - #{r[:path]}" }

    # Depth filtering
    puts "\n2. Depth-filtered search (max_depth: 2):"
    results = @search.search_with_depth(pattern: "product", max_depth: 2)
    puts "  Found #{results.size} results at depth ≤ 2:"
    results.each do |r|
      depth = r[:path]&.split(".")&.size || 0
      puts "    - #{r[:path]} (depth: #{depth})"
    end

    # Relevance ranking
    puts "\n3. Relevance-ranked search:"
    results = @search.search_ranked(pattern: "product")
    puts "  Results ranked by relevance:"
    results.take(5).each do |r|
      puts "    - #{r[:path]} (score: #{r[:relevance_score]})"
    end

    # Advanced combined search
    puts "\n4. Advanced search (depth + ranking):"
    results = @search.search_advanced(
      pattern: "product",
      max_depth: 2,
      ranked: true,
    )
    puts "  Combined results:"
    results.each do |r|
      puts "    - #{r[:path]} (score: #{r[:relevance_score]})"
    end

    # Regex search
    puts "\n5. Regex search:"
    results = @search.search(
      pattern: "^product_.*",
      regex: true,
    )
    puts "  Regex matches: #{results.size} result(s)"
    results.each { |r| puts "    - #{r[:id]}" }

    # Exact match
    puts "\n6. Exact match:"
    results = @search.search(
      pattern: "simple_example.product",
      exact: true,
    )
    puts "  Exact matches: #{results.size} result(s)"
  end

  def demonstrate_statistics
    print_section("Step 4: Repository Statistics (Phase 3)")

    # Schema categorization
    puts "1. Schemas by category:"
    categories = @repo.schemas_by_category
    categories.each do |category, schemas|
      next if schemas.empty?

      puts "  #{category}: #{schemas.size} schema(s)"
      schemas.each { |s| puts "    - #{s.id}" }
    end

    # Largest schemas
    puts "\n2. Largest schemas by element count:"
    largest = @repo.largest_schemas(5)
    largest.each do |item|
      puts "  - #{item[:schema].id}: #{item[:total_elements]} elements"
    end

    # Schema complexity
    puts "\n3. Schema complexity scores:"
    complex = @repo.schemas_by_complexity(5)
    complex.each do |item|
      puts "  - #{item[:schema].id}: complexity #{item[:complexity]}"
      schema = item[:schema]
      details = []
      details << "#{schema.entities&.size || 0} entities" if schema.entities&.any?
      details << "#{schema.types&.size || 0} types" if schema.types&.any?
      details << "#{schema.functions&.size || 0} functions" if schema.functions&.any?
      puts "    (#{details.join(', ')})" unless details.empty?
    end

    # Dependency statistics
    puts "\n4. Dependency statistics:"
    deps = @repo.dependency_statistics
    puts "  Total interfaces: #{deps[:total_interfaces]}"
    puts "  USE FROM: #{deps[:use_from_count]}"
    puts "  REFERENCE FROM: #{deps[:reference_from_count]}"

    if deps[:most_referenced].any?
      puts "  Most referenced schemas:"
      deps[:most_referenced].take(3).each do |schema_id, count|
        puts "    - #{schema_id}: #{count} references"
      end
    end
  end

  def demonstrate_validation
    print_section("Step 5: Package Validation (Phase 2)")

    # Basic validation
    puts "1. Basic validation:"
    validation = @repo.validate
    if validation[:valid?]
      puts "  ✓ Package is valid"
    else
      puts "  ✗ Validation failed:"
      validation[:errors].each do |error|
        puts "    - #{error[:message]}"
      end
    end

    # Strict validation
    puts "\n2. Strict validation (with completeness checks):"
    validation = @repo.validate(
      strict: true,
      check_completeness: true,
    )

    if validation[:valid?]
      puts "  ✓ Package passes strict validation"
    end

    if validation[:warnings]&.any?
      puts "  Warnings (#{validation[:warnings].size}):"
      validation[:warnings].take(3).each do |warning|
        puts "    - #{warning[:message]}"
      end
    end

    # Enhanced validation
    puts "\n3. Enhanced validation (all checks):"
    validation = @repo.validate(
      strict: true,
      check_interfaces: true,
      check_completeness: true,
      check_duplicates: true,
      detailed: false,
    )

    puts "  Validation result: #{validation[:valid?] ? '✓ Valid' : '✗ Invalid'}"
    puts "  Errors: #{validation[:errors]&.size || 0}"
    puts "  Warnings: #{validation[:warnings]&.size || 0}"
  end

  def print_header(text, char = "=")
    line = char * 70
    puts "\n#{line}"
    puts text.center(70)
    puts "#{line}\n"
  end

  def print_section(title)
    puts "\n#{title}"
    puts "-" * 70
  end
end

# Run demo
if __FILE__ == $PROGRAM_NAME
  begin
    LERDemo.new.run
  rescue StandardError => e
    puts "\nError: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end
