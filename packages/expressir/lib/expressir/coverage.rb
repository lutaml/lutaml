require "pathname"

module Expressir
  # Coverage module for calculating documentation coverage of EXPRESS entities
  module Coverage
    # Single source of truth: EXPRESS type name → Ruby class name pairs.
    # ENTITY_TYPE_MAP and CLASS_TO_EXPRESS_TYPE_MAP are derived from this
    # so the two never drift out of sync.
    TYPE_PAIRS = [
      ["TYPE", "Expressir::Model::Declarations::Type"],
      ["ENTITY", "Expressir::Model::Declarations::Entity"],
      ["CONSTANT", "Expressir::Model::Declarations::Constant"],
      ["FUNCTION", "Expressir::Model::Declarations::Function"],
      ["RULE", "Expressir::Model::Declarations::Rule"],
      ["PROCEDURE", "Expressir::Model::Declarations::Procedure"],
      ["SUBTYPE_CONSTRAINT", "Expressir::Model::Declarations::SubtypeConstraint"],
      ["PARAMETER", "Expressir::Model::Declarations::Parameter"],
      ["VARIABLE", "Expressir::Model::Declarations::Variable"],
      ["ATTRIBUTE", "Expressir::Model::Declarations::Attribute"],
      ["DERIVED_ATTRIBUTE", "Expressir::Model::Declarations::DerivedAttribute"],
      ["INVERSE_ATTRIBUTE", "Expressir::Model::Declarations::InverseAttribute"],
      ["UNIQUE_RULE", "Expressir::Model::Declarations::UniqueRule"],
      ["WHERE_RULE", "Expressir::Model::Declarations::WhereRule"],
      ["ENUMERATION_ITEM", "Expressir::Model::DataTypes::EnumerationItem"],
      ["INTERFACE", "Expressir::Model::Declarations::Interface"],
      ["INTERFACE_ITEM", "Expressir::Model::Declarations::InterfaceItem"],
      ["INTERFACED_ITEM", "Expressir::Model::Declarations::InterfacedItem"],
      ["SCHEMA_VERSION", "Expressir::Model::Declarations::SchemaVersion"],
      ["SCHEMA_VERSION_ITEM", "Expressir::Model::Declarations::SchemaVersionItem"],
    ].freeze

    # EXPRESS entity type name → Ruby class name.
    ENTITY_TYPE_MAP = TYPE_PAIRS.to_h.freeze

    # Short Ruby class name → EXPRESS entity type name.
    CLASS_TO_EXPRESS_TYPE_MAP = TYPE_PAIRS.to_h do |express_name, ruby_class|
      [ruby_class.split("::").last, express_name]
    end.freeze

    # Available TYPE subtypes based on data types
    TYPE_SUBTYPES = %w[
      AGGREGATE ARRAY BAG BINARY BOOLEAN ENUMERATION GENERIC GENERIC_ENTITY
      INTEGER LIST LOGICAL NUMBER REAL SELECT SET STRING
    ].freeze
    # Represents a documentation coverage report for EXPRESS schemas
    class Report
      attr_reader :repository, :schema_reports, :total_entities, :documented_entities,
                  :undocumented_entities, :ignored_files

      # Initialize a coverage report
      # @param repository [Expressir::Model::Repository] The repository to analyze
      # @param skip_types [Array<String>] Array of entity type names to skip from coverage
      # @param ignored_files [Hash] Hash mapping absolute file paths to their matched patterns
      def initialize(repository, skip_types = [], ignored_files = {})
        @repository = repository
        @skip_types = skip_types
        @ignored_files = ignored_files
        @schema_reports = []
        @total_entities = []
        @documented_entities = []
        @undocumented_entities = []

        process_repository
      end

      # Create a report from a repository
      # @param repository [Expressir::Model::Repository] The repository to analyze
      # @param skip_types [Array<String>] Array of entity type names to skip from coverage
      # @param ignored_files [Hash] Hash mapping absolute file paths to their matched patterns
      # @return [Report] The coverage report
      def self.from_repository(repository, skip_types = [], ignored_files = {})
        new(repository, skip_types, ignored_files)
      end

      # Create a report from a schema file
      # @param path [String] Path to the schema file
      # @param skip_types [Array<String>] Array of entity type names to skip from coverage
      # @param ignored_files [Hash] Hash mapping absolute file paths to their matched patterns
      # @return [Report] The coverage report
      def self.from_file(path, skip_types = [], ignored_files = {})
        repository = Expressir::Express::Parser.from_file(path)
        new(repository, skip_types, ignored_files)
      end

      # Calculate the overall coverage percentage
      # @return [Float] The coverage percentage
      def coverage_percentage
        return 100.0 if @total_entities.empty?

        (@documented_entities.size.to_f / @total_entities.size) * 100
      end

      # Get file-level reports
      # @return [Array<Hash>] Array of file report hashes
      def file_reports
        @schema_reports.map do |report|
          absolute_path = report[:schema].file
          relative_path = begin
            Pathname.new(absolute_path).relative_path_from(Pathname.pwd).to_s
          rescue ArgumentError
            # If paths are on different drives or otherwise incompatible,
            # fall back to the absolute path
            absolute_path
          end

          file_report = {
            "file" => relative_path,
            "file_basename" => File.basename(absolute_path),
            "directory" => File.dirname(absolute_path),
            "total" => report[:total].size,
            "documented" => report[:documented].size,
            "undocumented" => report[:undocumented],
            "coverage" => report[:coverage],
            "ignored" => report[:ignored] || false,
          }

          # Add matched pattern for ignored files
          if report[:ignored] && report[:matched_pattern]
            file_report["matched_pattern"] = report[:matched_pattern]
          end

          file_report
        end
      end

      # Get ignored file reports
      # @return [Array<Hash>] Array of ignored file report hashes
      def ignored_file_reports
        @schema_reports.select { |report| report[:ignored] }.map do |report|
          absolute_path = report[:schema].file
          relative_path = begin
            Pathname.new(absolute_path).relative_path_from(Pathname.pwd).to_s
          rescue ArgumentError
            # If paths are on different drives or otherwise incompatible,
            # fall back to the absolute path
            absolute_path
          end

          {
            "file" => relative_path,
            "file_basename" => File.basename(absolute_path),
            "directory" => File.dirname(absolute_path),
            "total" => report[:total].size,
            "documented" => report[:documented].size,
            "undocumented" => report[:undocumented],
            "coverage" => report[:coverage],
            "matched_pattern" => report[:matched_pattern],
          }
        end
      end

      # Get directory-level reports
      # @return [Array<Hash>] Array of directory report hashes
      def directory_reports
        # Group by directory (absolute path)
        by_directory = file_reports.group_by { |r| r["directory"] }

        # Aggregate stats for each directory
        by_directory.map do |directory, reports|
          # Convert directory to relative path
          relative_directory = begin
            Pathname.new(directory).relative_path_from(Pathname.pwd).to_s
          rescue ArgumentError
            # If paths are on different drives or otherwise incompatible,
            # fall back to the absolute path
            directory
          end

          total = reports.sum { |r| r["total"] }
          documented = reports.sum { |r| r["documented"] }
          coverage = total.positive? ? (documented.to_f / total) * 100 : 100.0

          {
            "directory" => relative_directory,
            "total" => total,
            "documented" => documented,
            "undocumented" => total - documented,
            "coverage" => coverage,
            "files" => reports.size,
          }
        end
      end

      # Convert report to a hash representation
      # @return [Hash] The report as a hash
      def to_h
        {
          "overall" => {
            "total" => @total_entities.size,
            "documented" => @documented_entities.size,
            "undocumented" => @undocumented_entities.size,
            "coverage" => coverage_percentage,
          },
          "directories" => directory_reports,
          "files" => file_reports,
        }
      end

      private

      # Process the repository and collect coverage information
      def process_repository
        return unless @repository

        @repository.schemas.each do |schema|
          schema_report = process_schema(schema)
          @schema_reports << schema_report

          # Only include non-ignored files in overall statistics
          unless schema_report[:ignored]
            @total_entities.concat(schema_report[:total])
            @documented_entities.concat(schema_report[:documented])
            @undocumented_entities.concat(schema_report[:undocumented].map do |entity|
              { schema: schema.id, entity: entity }
            end)
          end
        end
      end

      # Process a schema and collect coverage information
      # @param schema [Expressir::Model::Declarations::Schema] The schema to analyze
      # @return [Hash] A hash with coverage information
      def process_schema(schema)
        entities = Expressir::Coverage.find_entities(schema, @skip_types)
        documented = entities.select do |e|
          Expressir::Coverage.entity_documented?(e)
        end
        undocumented = entities - documented

        coverage = entities.empty? ? 100.0 : (documented.size.to_f / entities.size) * 100

        # Check if this schema file is ignored
        schema_file = File.expand_path(schema.file) if schema.file
        ignored = @ignored_files.key?(schema_file)
        matched_pattern = @ignored_files[schema_file] if ignored

        {
          schema: schema,
          total: entities,
          documented: documented,
          undocumented: undocumented.map { |e| format_entity(e) },
          coverage: coverage,
          ignored: ignored,
          matched_pattern: matched_pattern,
        }
      end

      # Format an entity for display
      # @param entity [Expressir::Model::ModelElement] The entity to format
      # @return [Hash] A hash with type and name of the entity
      def format_entity(entity)
        # Get class name (e.g., "Type" from "Expressir::Model::Declarations::Type")
        type_name = entity.class.name.split("::").last

        # Use proper mapping to EXPRESS convention
        express_type = CLASS_TO_EXPRESS_TYPE_MAP[type_name] || type_name.upcase

        # Return structured format
        {
          "type" => express_type,
          "name" => entity.id.to_s,
        }
      end
    end

    # Check if an entity has documentation (remarks)
    # @param entity [Expressir::Model::ModelElement] The entity to check
    # @return [Boolean] True if the entity has documentation
    def self.entity_documented?(entity)
      # Check for direct remarks (types with Identifier module have remarks)
      if entity.is_a?(Model::HasRemarks) && entity.remarks && !entity.remarks.empty?
        return true
      end

      # Check for remark_items (types with Identifier module have remark_items)
      if entity.is_a?(Model::HasRemarkItems) && entity.remark_items && !entity.remark_items.empty?
        return true
      end

      # For schema entities, check if there's a remark_item with their ID
      parent = entity.parent
      if parent.is_a?(Model::HasRemarkItems) && parent.remark_items
        entity_id = entity.id.to_s.downcase
        parent.remark_items.any? do |item|
          item.id.to_s.downcase == entity_id || item.id.to_s.downcase.include?("#{entity_id}.")
        end
      else
        false
      end
    end

    # Find all entities in a schema or repository
    # @param schema_or_repo [Expressir::Model::Declarations::Schema, Expressir::Model::Repository, Expressir::Model::ExpFile] The schema, repository, or file to analyze
    # @param skip_types [Array<String>] Array of entity type names to skip from coverage
    # @return [Array<Expressir::Model::ModelElement>] Array of entities
    def self.find_entities(schema_or_repo, skip_types = [])
      entities = []

      # Handle repository, exp_file, and schema inputs
      if schema_or_repo.is_a?(Expressir::Model::Repository)
        # If it's a repository, process all files
        schema_or_repo.files&.each do |file|
          file.schemas&.each do |schema|
            entities.concat(find_entities_in_schema(schema))
          end
        end
      elsif schema_or_repo.is_a?(Expressir::Model::ExpFile)
        # If it's an ExpFile, process all schemas in the file
        schema_or_repo.schemas&.each do |schema|
          entities.concat(find_entities_in_schema(schema))
        end
      else
        # If it's a schema, process it directly
        entities.concat(find_entities_in_schema(schema_or_repo))
      end

      # Filter out nil elements and ensure all have IDs
      # Note: Some ModelElement types (like Interface) don't have id
      entities = entities.compact.select do |e|
        e.is_a?(Model::HasId) && e.id
      end

      # Filter out skipped entity types
      apply_exclusions(entities, skip_types)
    end

    # Find all entities in a single schema
    # @param schema [Expressir::Model::Declarations::Schema] The schema to analyze
    # @return [Array<Expressir::Model::ModelElement>] Array of entities
    def self.find_entities_in_schema(schema)
      entities = []

      # Add all schema-level entities
      entities.concat(schema.constants) if schema.constants
      entities.concat(schema.types) if schema.types
      entities.concat(schema.entities) if schema.entities
      entities.concat(schema.functions) if schema.functions
      entities.concat(schema.rules) if schema.rules
      entities.concat(schema.procedures) if schema.procedures
      entities.concat(schema.subtype_constraints) if schema.subtype_constraints
      entities.concat(schema.interfaces) if schema.interfaces

      # Add nested entities recursively
      entities.concat(find_nested_entities(schema))

      entities
    end

    # Find all nested entities within a container (schema, entity, function, etc.)
    # @param container [Expressir::Model::ModelElement] The container to search
    # @return [Array<Expressir::Model::ModelElement>] Array of nested entities
    def self.find_nested_entities(container)
      entities = []

      # Handle different container types
      case container
      when Expressir::Model::Declarations::Schema
        # Schema-level nested entities
        container.types&.each do |type|
          entities.concat(find_nested_entities(type))
        end
        container.entities&.each do |entity|
          entities.concat(find_nested_entities(entity))
        end
        container.functions&.each do |function|
          entities.concat(find_nested_entities(function))
        end
        container.rules&.each do |rule|
          entities.concat(find_nested_entities(rule))
        end
        container.procedures&.each do |procedure|
          entities.concat(find_nested_entities(procedure))
        end
        container.interfaces&.each do |interface|
          entities.concat(find_nested_entities(interface))
        end

      when Expressir::Model::Declarations::Type
        # Type nested entities
        if container.enumeration_items
          entities.concat(container.enumeration_items)
        end

      when Expressir::Model::Declarations::Entity
        # Entity nested entities
        entities.concat(container.attributes) if container.attributes
        entities.concat(container.unique_rules) if container.unique_rules
        entities.concat(container.where_rules) if container.where_rules

      when Expressir::Model::Declarations::Function,
           Expressir::Model::Declarations::Procedure,
           Expressir::Model::Declarations::Rule
        # All three scope containers follow the same nested-entity pattern.
        # Derive the collection list from the model's own declaration rather
        # than maintaining three separate hand-coded branches.
        nested_attrs = container.class.collection_attributes_list - %i[
          statements remark_items where_rules informal_propositions applies_to
        ]
        nested_attrs.each do |attr|
          collection = container.public_send(attr)
          entities.concat(collection) if collection.is_a?(Array)
        end

        # Recursively find nested entities in nested scope containers
        %i[types entities functions procedures].each do |attr|
          collection = container.public_send(attr)
          collection&.each { |item| entities.concat(find_nested_entities(item)) }
        end

      when Expressir::Model::Declarations::Interface
        # Interface nested entities
        entities.concat(container.items) if container.items
      end

      entities
    end

    # Apply exclusions to filter out entities based on skip_types (supports both simple and TYPE:SUBTYPE syntax)
    # @param entities [Array<Expressir::Model::ModelElement>] The entities to filter
    # @param exclusions [Array<String>] Array of entity type names to exclude from coverage
    # @return [Array<Expressir::Model::ModelElement>] Filtered entities
    def self.apply_exclusions(entities, exclusions)
      filter_skipped_entities(entities, exclusions)
    end

    # Filter out entities based on skip_types (supports both simple and TYPE:SUBTYPE syntax)
    # @param entities [Array<Expressir::Model::ModelElement>] The entities to filter
    # @param skip_types [Array<String>] Array of entity type names to skip from coverage
    # @return [Array<Expressir::Model::ModelElement>] Filtered entities
    def self.filter_skipped_entities(entities, skip_types)
      return entities if skip_types.empty?

      # Parse skip_types into simple types, TYPE subtypes, and FUNCTION subtypes
      simple_skips = []
      type_subtype_skips = []
      function_subtype_skips = []

      skip_types.each do |skip_type|
        if skip_type.include?(":")
          # Handle TYPE:SUBTYPE and FUNCTION:SUBTYPE format
          main_type, subtype = skip_type.split(":", 2)
          if main_type == "TYPE" && TYPE_SUBTYPES.include?(subtype)
            type_subtype_skips << subtype
          elsif main_type == "FUNCTION" && subtype == "INNER"
            function_subtype_skips << subtype
          end
        else
          # Handle simple type format
          simple_skips << skip_type
        end
      end

      # Filter entities
      entities.reject do |entity|
        entity_class = entity.class.name

        # Check simple type exclusions
        # Convert entity class to EXPRESS type name for comparison
        class_name = entity_class.split("::").last
        express_type = CLASS_TO_EXPRESS_TYPE_MAP[class_name] || class_name.upcase

        if simple_skips.include?(express_type)
          true
        # Check TYPE subtype exclusions
        elsif entity_class == "Expressir::Model::Declarations::Type" && type_subtype_skips.any?
          entity_subtype = get_type_subtype(entity)
          type_subtype_skips.include?(entity_subtype)
        # Check FUNCTION:INNER exclusions — the whole inner-function
        # subtree is excluded, its parameters and nested declarations
        # included, not only the function entity itself
        elsif function_subtype_skips.include?("INNER") && within_inner_function?(entity)
          true
        else
          false
        end
      end
    end

    # Get the subtype of a TYPE entity based on its underlying_type
    # @param type_entity [Expressir::Model::Declarations::Type] The TYPE entity
    # @return [String] The subtype name (e.g., "SELECT", "ENUMERATION")
    def self.get_type_subtype(type_entity)
      return nil unless type_entity.is_a?(Model::Declarations::Type) && type_entity.underlying_type

      # Get the class name of the underlying type
      underlying_class = type_entity.underlying_type.class.name

      # Extract the data type name (e.g., "Select" from "Expressir::Model::DataTypes::Select")
      if underlying_class.start_with?("Expressir::Model::DataTypes::")
        data_type_name = underlying_class.split("::").last
        # Convert to uppercase (e.g., "Select" -> "SELECT")
        data_type_name.upcase
      else
        # For other types, try to extract the last part of the class name
        underlying_class.split("::").last&.upcase
      end
    end

    # Check if a function is an inner function (nested within another function, rule, or procedure)
    # @param function_entity [Expressir::Model::Declarations::Function] The function entity to check
    # @return [Boolean] True if the function is nested within another function, rule, or procedure
    def self.inner_function?(function_entity)
      return false unless function_entity.is_a?(Model::Declarations::Function) && function_entity.parent

      # Check if the parent is a function, rule, or procedure (not a schema)
      parent = function_entity.parent
      parent.is_a?(Expressir::Model::Declarations::Function) ||
        parent.is_a?(Expressir::Model::Declarations::Rule) ||
        parent.is_a?(Expressir::Model::Declarations::Procedure)
    end

    # Check if an entity is an inner function or a declaration belonging to one
    # (its parameters, nested types, nested functions, ...)
    # @param entity [Expressir::Model::ModelElement] The entity to check
    # @return [Boolean] True if the entity or any of its ancestors is an inner function
    def self.within_inner_function?(entity)
      current = entity
      while current
        return true if current.is_a?(Model::Declarations::Function) && inner_function?(current)

        current = current.respond_to?(:parent) ? current.parent : nil
      end
      false
    end
  end
end
