# frozen_string_literal: true

require_relative "validation_result"

module Lutaml
  module Qea
    module Validation
      # Base class for all validators providing common validation
      # infrastructure and helper methods
      #
      # @example Creating a custom validator
      #   class MyValidator < BaseValidator
      #     def validate
      #       check_required_field(:name)
      #       check_reference(:parent_id, :packages)
      #     end
      #   end
      class BaseValidator
        attr_reader :result, :context

        # Creates a new validator
        #
        # @param result [ValidationResult] Result object to populate
        # @param context [Hash] Validation context including database
        #   connection, document, etc.
        def initialize(result:, context: {})
          @result = result
          @context = context
        end

        # Performs validation and returns the result
        #
        # This method should be overridden by subclasses
        #
        # @return [ValidationResult]
        def validate
          raise NotImplementedError,
                "#{self.class} must implement #validate"
        end

        # Runs validation
        # Result is populated in the shared @result object
        #
        # @return [void]
        def call
          validate
        end

        protected

        # Returns the database connection from context
        #
        # @return [Lutaml::Qea::Database, nil]
        def database
          @context[:database]
        end

        # Returns the document being validated from context
        #
        # @return [Object, nil]
        def document
          @context[:document]
        end

        # Returns validation options from context
        #
        # @return [Hash]
        def options
          @context[:options] || {}
        end

        # Checks if a reference exists in a table
        #
        # @param entity_id [String, Integer] ID of the entity being validated
        # @param entity_name [String] Name of the entity being validated
        # @param entity_type [Symbol] Type of entity (e.g., :class,
        #   :association)
        # @param field [String] Field name containing the reference
        # @param reference_id [String, Integer] The referenced ID
        # @param table [String] Table to check for reference existence
        # @param id_column [String] ID column name in the reference table
        # @param category [Symbol] Validation category
        # @return [Boolean] True if reference exists, false otherwise
        def check_reference_exists( # rubocop:disable Metrics/MethodLength,Metrics/ParameterLists
          entity_id:,
          entity_name:,
          entity_type:,
          field:,
          reference_id:,
          table:,
          id_column: "ea_object_id",
          category: :missing_reference
        )
          return true if reference_id.nil? || reference_id.to_s.empty?

          exists = reference_exists?(table, id_column, reference_id)

          unless exists
            add_error(
              category: category,
              entity_type: entity_type,
              entity_id: entity_id,
              entity_name: entity_name,
              field: field,
              reference: reference_id.to_s,
              message: "#{field} references non-existent #{table} entry",
            )
          end

          exists
        end

        # Checks if a reference exists in the database
        #
        # @param table [String] Table name
        # @param id_column [String] ID column name
        # @param reference_id [String, Integer] The ID to check
        # @return [Boolean]
        def reference_exists?(table, id_column, reference_id)
          return false unless database

          collection = get_collection_for_table(table)
          return false unless collection

          collection.any? { |record| record.send(id_column) == reference_id }
        end

        # Maps table names to their corresponding collections in Database
        #
        # @param table [String] Table name (e.g., "t_package", "t_object")
        # @return [Array, nil] Collection array or nil if table not mapped
        def get_collection_for_table(table) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          case table
          when "t_package"
            database.packages
          when "t_object"
            database.objects.all
          when "t_attribute"
            database.attributes
          when "t_operation"
            database.operations
          when "t_operationparams"
            database.operation_params
          when "t_connector"
            database.connectors
          when "t_diagram"
            database.diagrams
          when "t_diagramobjects"
            database.diagram_objects
          when "t_diagramlinks"
            database.diagram_links
          when "t_objectconstraint"
            database.object_constraints
          when "t_objectproperties"
            database.object_properties
          when "t_taggedvalue"
            database.tagged_values
          when "t_attributetag"
            database.attribute_tags
          when "t_xref"
            database.xrefs
          when "t_stereotypes"
            database.stereotypes
          when "t_datatypes"
            database.datatypes
          when "t_constrainttypes"
            database.constraint_types
          when "t_connectortypes"
            database.connector_types
          when "t_diagramtypes"
            database.diagram_types
          when "t_objecttypes"
            database.object_types
          when "t_statustypes"
            database.status_types
          when "t_complexitytypes"
            database.complexity_types
          end
        end

        # Adds an error to the validation result
        #
        # @param args [Hash] Message attributes
        # @return [ValidationMessage]
        def add_error(**args)
          @result.add_error(**args)
        end

        # Adds a warning to the validation result
        #
        # @param args [Hash] Message attributes
        # @return [ValidationMessage]
        def add_warning(**args)
          @result.add_warning(**args)
        end

        # Adds an info message to the validation result
        #
        # @param args [Hash] Message attributes
        # @return [ValidationMessage]
        def add_info(**args)
          @result.add_info(**args)
        end

        # Checks if a value is present (not nil and not empty)
        #
        # @param value [Object] Value to check
        # @return [Boolean]
        def present?(value)
          !value.nil? && (value.respond_to?(:empty?) ? !value.empty? : true)
        end

        # Finds entity name from database
        #
        # @param table [String] Table name
        # @param id_column [String] ID column name
        # @param name_column [String] Name column name
        # @param id [String, Integer] Entity ID
        # @return [String, nil] Entity name or nil if not found
        def find_entity_name(table, id_column, name_column, id)
          return nil unless database

          collection = get_collection_for_table(table)
          return nil unless collection

          record = collection.find { |r| r.send(id_column) == id }
          record&.send(name_column)
        end

        # Validates a collection of entities
        #
        # @param entities [Array] Collection of entities to validate
        # @yield [entity] Validation block for each entity
        # @return [ValidationResult]
        def validate_each(entities, &block)
          entities.each(&block)
          @result
        end

        # Resolves package ID to full qualified path
        #
        # @param package_id [Integer] Package ID to resolve
        # @return [String] Qualified path like
        # "Root::ModelA::PackageB (package_id: 123)"
        def resolve_package_path(package_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return "Root" if package_id.nil? || package_id.zero?

          path_parts = []
          current_id = package_id

          # Walk up the parent chain to build full path
          while current_id && !current_id.zero?
            package = database.packages.find { |p| p.package_id == current_id }

            if package
              path_parts.unshift(package.name)
              # Get parent_id for next iteration
              current_id = package.parent_id
            else
              # Package not found, return what we have with ID
              path_parts.unshift("Unknown")
              break
            end
          end

          if path_parts.empty?
            "Unknown (package_id: #{package_id})"
          else
            "#{path_parts.join('::')} (package_id: #{package_id})"
          end
        end

        # Resolves object to qualified class name including package path
        #
        # @param object_id [Integer] Object ID to resolve
        # @param object_name [String, nil] Object name if already known
        # @return [String] Qualified name like "Package::ClassName
        # (object_id: 456)"
        def resolve_class_path(object_id, object_name = nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return "Unknown (object_id: #{object_id})" if object_id.nil?

          # Get object from collection directly
          object = database.objects.all.find do |obj|
            obj.ea_object_id == object_id
          end
          return "Unknown (object_id: #{object_id})" unless object

          # Get class name
          class_name = object_name || object.name
          package_id = object.package_id

          if package_id && !package_id.zero?
            package_path = resolve_package_path(package_id)
            # Remove the package_id suffix from package path and add class
            base_package_path = package_path.sub(/ \(package_id: \d+\)$/, "")
            "#{base_package_path}::" \
              "#{class_name || 'Unknown'} (object_id: #{object_id})"
          else
            "#{class_name || 'Unknown'} (object_id: #{object_id})"
          end
        end
      end
    end
  end
end
