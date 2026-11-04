# frozen_string_literal: true

module Lutaml
  module Xsd
    # Classifies schemas in a repository by their role and resolution status
    # Follows single responsibility principle: only classification logic
    class SchemaClassifier
      attr_reader :repository

      def initialize(repository)
        @repository = repository
      end

      # Classify all schemas in repository
      # Returns structured classification following MECE principle
      # @return [Hash] Classification results with categories
      def classify
        {
          entrypoint_schemas: classify_entrypoint_schemas,
          dependency_schemas: classify_dependency_schemas,
          fully_resolved: fully_resolved_schemas,
          partially_resolved: partially_resolved_schemas,
          summary: generate_summary,
        }
      end

      private

      # Schemas explicitly loaded (from files list)
      # @return [Array<SchemaClassificationInfo>]
      def classify_entrypoint_schemas
        return [] unless repository.files

        repository.files.filter_map do |file_path|
          schema = get_schema_by_path(file_path)
          next unless schema

          SchemaClassificationInfo.new(
            schema: schema,
            location: file_path,
            category: :entrypoint,
          )
        end
      end

      # Schemas discovered through imports/includes
      # @return [Array<SchemaClassificationInfo>]
      def classify_dependency_schemas
        entrypoint_paths = repository.files || []
        all_schemas = get_all_schemas

        all_schemas.except(*entrypoint_paths).map do |path, schema|
          SchemaClassificationInfo.new(
            schema: schema,
            location: path,
            category: :dependency,
          )
        end
      end

      # Schemas where all references resolve within package
      # @return [Array<SchemaClassificationInfo>]
      def fully_resolved_schemas
        all_classified = []

        get_all_schemas.each do |path, schema|
          info = SchemaClassificationInfo.new(
            schema: schema,
            location: path,
            category: determine_category(path),
          )

          all_classified << info if info.fully_resolved?
        end

        all_classified
      end

      # Schemas with some unresolved references
      # @return [Array<SchemaClassificationInfo>]
      def partially_resolved_schemas
        all_classified = []

        get_all_schemas.each do |path, schema|
          info = SchemaClassificationInfo.new(
            schema: schema,
            location: path,
            category: determine_category(path),
          )

          all_classified << info unless info.fully_resolved?
        end

        all_classified
      end

      # Generate summary statistics
      # @return [Hash] Summary counts
      def generate_summary
        entrypoint = classify_entrypoint_schemas
        dependency = classify_dependency_schemas
        fully_resolved = fully_resolved_schemas
        partially_resolved = partially_resolved_schemas

        {
          total_schemas: get_all_schemas.size,
          entrypoint_count: entrypoint.size,
          dependency_count: dependency.size,
          fully_resolved_count: fully_resolved.size,
          partially_resolved_count: partially_resolved.size,
          resolution_percentage: calculate_resolution_percentage(
            fully_resolved.size,
            get_all_schemas.size,
          ),
        }
      end

      # Get all processed schemas
      # @return [Hash] All schemas from the repository
      def get_all_schemas
        Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
      end

      # Get schema by file path
      # @param path [String] File path
      # @return [Schema, nil] The schema or nil
      def get_schema_by_path(path)
        get_all_schemas[path]
      end

      # Determine if path is an entrypoint
      # @param path [String] Schema path
      # @return [Symbol] :entrypoint or :dependency
      def determine_category(path)
        if repository.files&.include?(path)
          :entrypoint
        else
          :dependency
        end
      end

      # Calculate resolution percentage
      # @param resolved [Integer] Number of fully resolved schemas
      # @param total [Integer] Total number of schemas
      # @return [Float] Percentage as decimal (0.0 to 100.0)
      def calculate_resolution_percentage(resolved, total)
        return 0.0 if total.zero?

        ((resolved.to_f / total) * 100).round(2)
      end
    end

    # Value object for schema classification info
    class SchemaClassificationInfo
      attr_reader :location, :category, :namespace, :elements_count,
                  :types_count, :resolution_status, :external_refs

      def initialize(schema:, location:, category:)
        @location = location
        @category = category
        @namespace = schema.target_namespace
        @elements_count = schema.element.size
        @complex_types_count = schema.complex_type.size
        @simple_types_count = schema.simple_type.size
        @types_count = @complex_types_count + @simple_types_count
        @imports_count = schema.import.size
        @includes_count = schema.include.size
        @external_refs = extract_external_references(schema)
        @resolution_status = determine_resolution_status
      end

      # Check if schema is fully resolved
      # @return [Boolean] True if all references are resolved
      def fully_resolved?
        @resolution_status == :fully_resolved
      end

      # Check if schema is partially resolved
      # @return [Boolean] True if some references are unresolved
      def partially_resolved?
        @resolution_status == :partially_resolved
      end

      # Convert to hash representation
      # @return [Hash] Hash representation of the classification info
      def to_h
        {
          location: @location,
          filename: File.basename(@location),
          category: @category,
          namespace: @namespace || "(no namespace)",
          elements_count: @elements_count,
          types_count: @types_count,
          complex_types_count: @complex_types_count,
          simple_types_count: @simple_types_count,
          imports_count: @imports_count,
          includes_count: @includes_count,
          resolution_status: @resolution_status,
          external_refs_count: @external_refs.size,
        }
      end

      private

      # Extract external references from schema
      # @param schema [Schema] The schema to analyze
      # @return [Array<Hash>] List of external references
      def extract_external_references(schema)
        refs = []

        # Check imports - handle both Import objects and Schema objects
        schema.import.each do |import|
          next unless import.namespace || import.target_namespace

          refs << {
            type: :import,
            namespace: import.namespace || import.target_namespace,
            schema_location: import.schema_path,
          }
        end

        # Check includes - handle both Include objects and Schema objects
        schema.include.each do |include|
          next unless include.schema_path || include.is_a?(Schema)

          refs << {
            type: :include,
            schema_location: include.schema_path,
          }
        end

        refs
      end

      # Determine resolution status based on external references
      # @return [Symbol] :fully_resolved or :partially_resolved
      def determine_resolution_status
        # Check if all external references are resolved
        unresolved_refs = @external_refs.select do |ref|
          location = ref[:schema_location]
          location && !Lutaml::Xml::Schema::Xsd::Schema.schema_processed?(location)
        end

        if unresolved_refs.empty?
          :fully_resolved
        else
          :partially_resolved
        end
      end
    end
  end
end
