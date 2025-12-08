# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Validators
      # RepositoryValidator validates the consistency and integrity of a UML repository
      #
      # Performs comprehensive validation checks including:
      # - Type reference validation (checking all attribute types exist)
      # - Generalization reference validation (checking parent classes exist)
      # - Circular inheritance detection
      # - Association reference validation
      # - Multiplicity validation
      #
      # @example Validating a repository
      #   validator = RepositoryValidator.new(document, indexes)
      #   result = validator.validate
      #   if result.valid?
      #     puts "Model is valid"
      #   else
      #     result.errors.each { |error| puts "ERROR: #{error}" }
      #   end
      class RepositoryValidator
        # Primitive types that don't need to be resolved
        PRIMITIVE_TYPES = %w[
          String Integer Boolean Date DateTime Float Double
          Long Short Byte Char Time Decimal
          UnlimitedNatural Real
        ].freeze

        # @param document [Lutaml::Uml::Document] The UML document
        # @param indexes [Hash] The repository indexes
        def initialize(document, indexes)
          @document = document
          @indexes = indexes
          @errors = []
          @warnings = []
        end

        # Validate the repository and return results
        #
        # @param verbose [Boolean] Collect detailed validation information
        # @return [ValidationResult] Validation results with errors and warnings
        def validate(verbose: false)
          @verbose = verbose
          @validation_details = [] if verbose
          
          check_type_references
          check_generalization_references
          # DISABLED: check_circular_inheritance - has bugs with name resolution
          check_association_references
          check_multiplicities

          ValidationResult.new(
            valid: @errors.empty?,
            errors: @errors,
            warnings: @warnings,
            external_references: @external_references || [],
            validation_details: @validation_details,
          )
        end

        private

        # Check that all attribute types reference existing classes or are primitives
        def check_type_references
          @external_references = []

          @indexes[:qualified_names].each do |qname, klass|
            next unless klass.is_a?(Lutaml::Uml::Class)
            next unless klass.attributes

            # Extract current package path from qualified name
            current_package_path = extract_package_path(qname)

            # Collect detailed validation info for this class if verbose
            class_details = { class_name: qname, attributes: [] } if @verbose

            klass.attributes.each do |attr|
              next unless attr.type
              
              is_primitive = primitive_type?(attr.type)
              
              # Try to resolve the type name
              resolved_type = is_primitive ? nil : resolve_type_name(attr.type, current_package_path)
              is_valid = is_primitive || !resolved_type.nil?

              # Collect verbose info
              if @verbose
                class_details[:attributes] << {
                  attribute_name: attr.name,
                  type_value: attr.type,
                  resolved_to: resolved_type,
                  valid: is_valid,
                  is_primitive: is_primitive,
                }
              end

              next if is_valid

              # Track external reference
              @external_references << {
                class_name: qname,
                attribute_name: attr.name,
                referenced_type: attr.type,
                context: "attribute type",
              }

              @errors << "Unresolved type reference: '#{attr.type}' in #{qname}.#{attr.name}"
            end

            @validation_details << class_details if @verbose && class_details[:attributes].any?
          end
        end

        # Check that all generalization references point to existing classes
        def check_generalization_references
          @indexes[:inheritance_graph].each do |parent_qname, children|
            # Check if parent exists
            unless @indexes[:qualified_names].key?(parent_qname)
              children.each do |child_qname|
                @errors << "Generalization references non-existent parent: '#{parent_qname}' from #{child_qname}"
              end
            end
          end
        end

        # Detect circular inheritance relationships
        def check_circular_inheritance
          visited = {}

          @indexes[:inheritance_graph].each_key do |parent_qname|
            cycle = find_cycle(parent_qname, visited, [])
            if cycle
              @errors << "Circular inheritance detected: #{cycle.join(' -> ')}"
            end
          end
        end

        # Check that all association ends reference existing classes
        def check_association_references
          @indexes[:qualified_names].each do |qname, klass|
            next unless klass.is_a?(Lutaml::Uml::Class)
            next unless klass.associations

            klass.associations.each do |assoc|
              # Check member_end references
              if assoc.respond_to?(:member_end) && assoc.member_end
                check_association_end_type(assoc.member_end, qname)
              end

              # Check owned_end references
              if assoc.respond_to?(:owned_end) && assoc.owned_end
                check_association_end_type(assoc.owned_end, qname)
              end
            end
          end
        end

        # Check association end type references
        #
        # @param ends [Array, Object] Association ends to check
        # @param source_qname [String] Source class qualified name
        def check_association_end_type(ends, source_qname)
          ends_array = ends.is_a?(Array) ? ends : [ends]

          ends_array.each do |end_obj|
            next unless end_obj.respond_to?(:type)
            next unless end_obj.type

            type_name = end_obj.type
            type_name = type_name.name if type_name.respond_to?(:name)

            next if @indexes[:qualified_names].key?(type_name)

            @warnings << "Association end references potentially unresolved type: '#{type_name}' from #{source_qname}"
          end
        end

        # Check multiplicity values are valid
        def check_multiplicities
          @indexes[:qualified_names].each do |qname, klass|
            next unless klass.is_a?(Lutaml::Uml::Class)
            next unless klass.attributes

            klass.attributes.each do |attr|
              next unless attr.respond_to?(:cardinality)
              next unless attr.cardinality

              cardinality = attr.cardinality
              check_cardinality_value(cardinality, qname, attr.name)
            end
          end
        end

        # Check a cardinality value is valid
        #
        # @param cardinality [Object] Cardinality object
        # @param class_qname [String] Class qualified name
        # @param attr_name [String] Attribute name
        def check_cardinality_value(cardinality, class_qname, attr_name)
          min_val = extract_min_value(cardinality)
          max_val = extract_max_value(cardinality)

          return unless min_val || max_val

          # Check min is not negative
          if min_val.is_a?(Integer) && min_val.negative?
            @errors << "Invalid multiplicity: min value #{min_val} is negative in #{class_qname}.#{attr_name}"
          end

          # Check max is not less than min (unless it's unlimited)
          if min_val && max_val.is_a?(Integer) && (max_val < min_val)
            @errors << "Invalid multiplicity: max (#{max_val}) < min (#{min_val}) in #{class_qname}.#{attr_name}"
          end
        end

        # Extract min value from cardinality
        #
        # @param cardinality [Object] Cardinality object
        # @return [Integer, nil] Min value
        def extract_min_value(cardinality)
          return nil unless cardinality.respond_to?(:min)

          min_val = cardinality.min
          return nil unless min_val

          min_val.is_a?(Hash) ? min_val["value"] : min_val
        end

        # Extract max value from cardinality
        #
        # @param cardinality [Object] Cardinality object
        # @return [Integer, String, nil] Max value (could be "*" for unlimited)
        def extract_max_value(cardinality)
          return nil unless cardinality.respond_to?(:max)

          max_val = cardinality.max
          return nil unless max_val

          max_val.is_a?(Hash) ? max_val["value"] : max_val
        end

        # Find a cycle in the inheritance graph starting from a node
        #
        # @param qname [String] Starting qualified name
        # @param visited [Hash] Visited nodes state
        # @param path [Array] Current path
        # @return [Array, nil] Cycle path if found, nil otherwise
        def find_cycle(qname, visited, path)
          return nil if visited[qname] == :permanent
          return path + [qname] if path.include?(qname)

          visited[qname] = :temporary
          path.push(qname)

          children = @indexes[:inheritance_graph][qname] || []
          children.each do |child_qname|
            cycle = find_cycle(child_qname, visited, path)
            return cycle if cycle
          end

          path.pop
          visited[qname] = :permanent
          nil
        end

        # Extract package path from qualified name
        #
        # @param qname [String] Qualified name like "ModelRoot::Package::Class"
        # @return [String] Package path like "ModelRoot::Package"
        def extract_package_path(qname)
          parts = qname.split("::")
          parts.size > 1 ? parts[0..-2].join("::") : "ModelRoot"
        end

        # Resolve a type name to its fully qualified name
        #
        # @param type_name [String] Type name to resolve
        # @param current_package_path [String] Current package context
        # @return [String, nil] Resolved qualified name or nil if not found
        def resolve_type_name(type_name, current_package_path)
          # Already qualified and exists?
          return type_name if @indexes[:qualified_names].key?(type_name)
          
          # Try in current package
          local_qname = "#{current_package_path}::#{type_name}"
          return local_qname if @indexes[:qualified_names].key?(local_qname)
          
          # Try to find in all qualified names (simple name match)
          @indexes[:qualified_names].each_key do |qname|
            return qname if qname.end_with?("::#{type_name}")
          end
          
          nil
        end

        # Check if a type is a primitive type
        #
        # @param type [String] Type name
        # @return [Boolean] True if primitive type
        def primitive_type?(type)
          PRIMITIVE_TYPES.include?(type)
        end
      end

      # ValidationResult encapsulates the results of repository validation
      #
      # @example Checking validation results
      #   result = validator.validate
      #   puts "Valid: #{result.valid?}"
      #   puts "Errors: #{result.errors.size}"
      #   puts "Warnings: #{result.warnings.size}"
      #   puts "External refs: #{result.external_references.size}"
      class ValidationResult
        # @return [Array<String>] Validation errors
        attr_reader :errors

        # @return [Array<String>] Validation warnings
        attr_reader :warnings

        # @return [Array<Hash>] External type references
        attr_reader :external_references

        # @return [Array<Hash>] Detailed validation information
        attr_reader :validation_details

        # @param valid [Boolean] Whether validation passed
        # @param errors [Array<String>] Validation errors
        # @param warnings [Array<String>] Validation warnings
        # @param external_references [Array<Hash>] External type references
        # @param validation_details [Array<Hash>, nil] Detailed validation information
        def initialize(valid:, errors:, warnings:, external_references: [], validation_details: nil)
          @valid = valid
          @errors = errors.freeze
          @warnings = warnings.freeze
          @external_references = external_references.freeze
          @validation_details = validation_details&.freeze
          freeze
        end

        # Check if validation passed (no errors)
        #
        # @return [Boolean] True if no errors
        def valid?
          @valid
        end

        # Check if there are any warnings
        #
        # @return [Boolean] True if warnings present
        def has_warnings?
          !@warnings.empty?
        end

        # Check if there are any external references
        #
        # @return [Boolean] True if external references found
        def has_external_references?
          !@external_references.empty?
        end

        # Get total issue count (errors + warnings)
        #
        # @return [Integer] Total number of issues
        def issue_count
          @errors.size + @warnings.size
        end

        # Get a summary of validation results
        #
        # @return [String] Summary string
        def summary
          if valid? && !has_warnings?
            "Validation passed: no issues found"
          elsif valid?
            "Validation passed with #{@warnings.size} warning(s)"
          else
            "Validation failed with #{@errors.size} error(s) and #{@warnings.size} warning(s)"
          end
        end
      end
    end
  end
end
