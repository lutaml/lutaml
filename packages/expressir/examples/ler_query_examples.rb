#!/usr/bin/env ruby
# frozen_string_literal: true

# LER Query Examples
# Demonstrates real-world query patterns using the SearchEngine and Repository APIs

require "expressir"

# Example 1: Loading and basic queries
def example_basic_queries
  puts "\n=== Example 1: Basic Queries ==="

  # Load package
  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # List all entities
  entities = search_engine.list(type: "entity")
  puts "Total entities: #{entities.size}"
  puts "First 5 entities:"
  entities.take(5).each do |e|
    puts "  - #{e[:schema]}.#{e[:id]}"
  end

  # List types by category
  select_types = search_engine.list(type: "type", category: "select")
  puts "\nSELECT types: #{select_types.size}"
  select_types.take(5).each do |t|
    puts "  - #{t[:schema]}.#{t[:id]} [#{t[:category]}]"
  end
end

# Example 2: Pattern matching with wildcards
def example_wildcard_patterns
  puts "\n=== Example 2: Wildcard Pattern Matching ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # Find all entities starting with "action"
  results = search_engine.search(pattern: "action*", type: "entity")
  puts "Entities starting with 'action': #{results.size}"
  results.each do |r|
    puts "  - #{r[:path]}"
  end

  # Find attributes named "id" in any entity
  id_attrs = search_engine.search(pattern: "*.*.id", type: "attribute")
  puts "\nAttributes named 'id': #{id_attrs.size}"
  id_attrs.take(10).each do |attr|
    puts "  - #{attr[:path]}"
  end

  # Find all elements in a specific schema
  schema_elements = search_engine.search(pattern: "action_schema.*",
                                         type: "entity")
  puts "\nEntities in action_schema: #{schema_elements.size}"
end

# Example 3: Advanced searching
def example_advanced_search
  puts "\n=== Example 3: Advanced Search Features ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # Regex search for entities with specific pattern
  results = search_engine.search(
    pattern: "^applied_.*_assignment$",
    type: "entity",
    regex: true,
  )
  puts "Entities matching regex pattern: #{results.size}"
  results.each do |r|
    puts "  - #{r[:id]} (#{r[:schema]})"
  end

  # Case-sensitive search
  case_results = search_engine.search(
    pattern: "Action",
    type: "entity",
    case_sensitive: true,
  )
  puts "\nCase-sensitive 'Action': #{case_results.size}"

  # Exact match
  exact = search_engine.search(
    pattern: "action_schema.action",
    type: "entity",
    exact: true,
  )
  puts "\nExact match: #{exact.size} result(s)"
end

# Example 4: Schema-specific queries
def example_schema_queries
  puts "\n=== Example 4: Schema-Specific Queries ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # List entities in specific schema
  schema_entities = search_engine.list(
    type: "entity",
    schema: "action_schema",
  )
  puts "Entities in action_schema: #{schema_entities.size}"

  # Search within specific schema
  results = search_engine.search(
    pattern: "action*",
    type: "entity",
    schema: "action_schema",
  )
  puts "Matching entities in action_schema: #{results.size}"

  # List all types in a schema
  types = search_engine.list(
    type: "type",
    schema: "support_resource_schema",
  )
  puts "Types in support_resource_schema: #{types.size}"
end

# Example 5: Finding specific attributes
def example_attribute_search
  puts "\n=== Example 5: Attribute Search ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # Find all attributes
  all_attrs = search_engine.list(type: "attribute")
  puts "Total attributes: #{all_attrs.size}"

  # Find attributes with specific name
  name_attrs = search_engine.search(pattern: "*.*. name", type: "attribute")
  puts "Attributes named 'name': #{name_attrs.size}"

  # Find derived attributes
  derived = search_engine.list(type: "derived_attribute")
  puts "Total derived attributes: #{derived.size}"

  # Find inverse attributes
  inverse = search_engine.list(type: "inverse_attribute")
  puts "Total inverse attributes: #{inverse.size}"
end

# Example 6: Repository statistics
def example_statistics
  puts "\n=== Example 6: Repository Statistics ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")

  stats = repo.statistics
  puts "Package Statistics:"
  puts "  Schemas: #{stats[:total_schemas]}"
  puts "  Entities: #{stats[:total_entities]}"
  puts "  Types: #{stats[:total_types]}"
  puts "  Functions: #{stats[:total_functions]}"
  puts "  Rules: #{stats[:total_rules]}"
  puts "  Procedures: #{stats[:total_procedures]}"

  puts "\nTypes by category:"
  stats[:types_by_category].each do |category, count|
    puts "  #{category}: #{count}"
  end

  puts "\nTop schemas by entity count:"
  stats[:entities_by_schema]
    .sort_by { |_, count| -count }
    .take(10)
    .each do |schema, count|
      puts "  #{schema}: #{count} entities"
    end

  puts "\nInterface usage:"
  puts "  USE FROM: #{stats[:interfaces][:use_from]}"
  puts "  REFERENCE FROM: #{stats[:interfaces][:reference_from]}"
end

# Example 7: Validation
def example_validation
  puts "\n=== Example 7: Package Validation ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")

  # Basic validation
  validation = repo.validate
  if validation[:valid?]
    puts "✓ Package is valid"
  else
    puts "✗ Validation failed:"
    validation[:errors].each do |error|
      puts "  - #{error[:message]}"
    end
  end

  # Strict validation with warnings
  strict_validation = repo.validate(strict: true)
  if strict_validation[:warnings]&.any?
    puts "\nWarnings:"
    strict_validation[:warnings].each do |warning|
      puts "  - #{warning[:message]}"
    end
  end
end

# Example 8: Finding functions and procedures
def example_functions_procedures
  puts "\n=== Example 8: Functions and Procedures ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # List all functions
  functions = search_engine.list(type: "function")
  puts "Total functions: #{functions.size}"
  functions.take(5).each do |f|
    puts "  - #{f[:schema]}.#{f[:id]}"
  end

  # Search for specific function
  results = search_engine.search(pattern: "bag_to_set", type: "function")
  if results.any?
    puts "\nFound 'bag_to_set' function:"
    results.each do |r|
      puts "  - #{r[:path]}"
    end
  end

  # List all procedures
  procedures = search_engine.list(type: "procedure")
  puts "\nTotal procedures: #{procedures.size}"
end

# Example 9: Collecting all element types
def example_all_element_types
  puts "\n=== Example 9: All Element Types ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  puts "Element counts by type:"
  Expressir::Model::SearchEngine::ELEMENT_TYPES.each do |elem_type|
    count = search_engine.count(type: elem_type)
    puts "  #{elem_type}: #{count}" if count.positive?
  end
end

# Example 10: Complex queries combining multiple criteria
def example_complex_queries
  puts "\n=== Example 10: Complex Combined Queries ==="

  repo = Expressir::Model::Repository.from_package("demo_activity.ler")
  search_engine = Expressir::Model::SearchEngine.new(repo)

  # Find all SELECT types starting with "action"
  results = search_engine.search(
    pattern: "action*",
    type: "type",
    category: "select",
  )
  puts "SELECT types starting with 'action': #{results.size}"

  # Find entities in specific schema matching pattern
  results = search_engine.search(
    pattern: "*_assignment",
    type: "entity",
    schema: "Activity_mim",
  )
  puts "Assignment entities in Activity_mim: #{results.size}"
  results.each do |r|
    puts "  - #{r[:id]}"
  end

  # Count constants in schema
  const_count = search_engine.count(
    type: "constant",
    schema: "support_resource_schema",
  )
  puts "\nConstants in support_resource_schema: #{const_count}"
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    example_basic_queries
    example_wildcard_patterns
    example_advanced_search
    example_schema_queries
    example_attribute_search
    example_statistics
    example_validation
    example_functions_procedures
    example_all_element_types
    example_complex_queries

    puts "\n=== All Examples Completed Successfully ==="
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end
