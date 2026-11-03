# frozen_string_literal: true

module Lutaml
  module Xsd
    # Validates that a schema repository package is fully resolved
    # Checks that all type, element, attribute, and group references
    # are resolvable within the package
    class PackageValidator
      attr_reader :errors, :warnings, :repository

      def initialize(repository)
        @repository = repository
        @errors = []
        @warnings = []
      end

      # Validate that all references in the package are fully resolved
      # @return [Hash] Validation results with errors, warnings, and statistics
      def validate_full_resolution
        @errors = []
        @warnings = []

        # Check all type references
        validate_type_references

        # Check all element references
        validate_element_references

        # Check all attribute references
        validate_attribute_references

        # Check all group references
        validate_group_references

        # Check all attribute group references
        validate_attribute_group_references

        # Check imports/includes are all resolved
        validate_imports_and_includes

        {
          valid: @errors.empty?,
          errors: @errors,
          warnings: @warnings,
          statistics: {
            types_checked: count_type_references,
            elements_checked: count_element_references,
            attributes_checked: count_attribute_references,
            groups_checked: count_group_references,
            attribute_groups_checked: count_attribute_group_references,
            all_resolved: @errors.empty?,
          },
        }
      end

      private

      # Validate all type references in elements and attributes
      def validate_type_references
        all_schemas.each do |schema|
          schema_namespace = schema.target_namespace

          # Check elements with type references
          schema.element.each do |elem|
            next unless elem.type
            next if builtin_type?(elem.type)

            # Qualify unprefixed types with schema's namespace
            qualified_type = qualify_type_reference(elem.type, schema_namespace)
            result = repository.find_type(qualified_type)
            next if result&.resolved?

            @errors << "Unresolved type reference: #{elem.type} " \
                       "in element #{elem.name} " \
                       "(#{schema_location(schema)})"
          end

          # Check attributes with type references
          schema.attribute.each do |attr|
            next unless attr.type
            next if builtin_type?(attr.type)

            # Qualify unprefixed types with schema's namespace
            qualified_type = qualify_type_reference(attr.type, schema_namespace)
            result = repository.find_type(qualified_type)
            next if result&.resolved?

            @errors << "Unresolved type reference: #{attr.type} " \
                       "in attribute #{attr.name} " \
                       "(#{schema_location(schema)})"
          end

          # Check complex types with base type references
          validate_complex_type_references(schema.complex_type, schema)

          # Check simple types with base type references
          validate_simple_type_references(schema.simple_type, schema)
        end
      end

      # Validate complex type base references
      def validate_complex_type_references(complex_types, schema)
        schema_namespace = schema.target_namespace

        complex_types.each do |ct|
          # Check extension bases
          if ct.complex_content&.extension&.base
            base = ct.complex_content.extension.base
            next if builtin_type?(base)

            # Qualify unprefixed types with schema's namespace
            qualified_type = qualify_type_reference(base, schema_namespace)
            result = repository.find_type(qualified_type)
            unless result&.resolved?
              @errors << "Unresolved base type: #{base} " \
                         "in complexType #{ct.name} " \
                         "(#{schema_location(schema)})"
            end
          end

          # Check restriction bases
          if ct.complex_content&.restriction&.base
            base = ct.complex_content.restriction.base
            next if builtin_type?(base)

            # Qualify unprefixed types with schema's namespace
            qualified_type = qualify_type_reference(base, schema_namespace)
            result = repository.find_type(qualified_type)
            unless result&.resolved?
              @errors << "Unresolved base type: #{base} " \
                         "in complexType #{ct.name} " \
                         "(#{schema_location(schema)})"
            end
          end

          # Check simple content bases
          if ct.simple_content&.extension&.base
            base = ct.simple_content.extension.base
            next if builtin_type?(base)

            # Qualify unprefixed types with schema's namespace
            qualified_type = qualify_type_reference(base, schema_namespace)
            result = repository.find_type(qualified_type)
            unless result&.resolved?
              @errors << "Unresolved base type: #{base} " \
                         "in complexType #{ct.name} " \
                         "(#{schema_location(schema)})"
            end
          end

          if ct.simple_content&.restriction&.base
            base = ct.simple_content.restriction.base
            next if builtin_type?(base)

            # Qualify unprefixed types with schema's namespace
            qualified_type = qualify_type_reference(base, schema_namespace)
            result = repository.find_type(qualified_type)
            unless result&.resolved?
              @errors << "Unresolved base type: #{base} " \
                         "in complexType #{ct.name} " \
                         "(#{schema_location(schema)})"
            end
          end

          # Check nested elements in sequences, choices, etc.
          check_element_refs_in_complex_type(ct, schema)
        end
      end

      # Validate simple type base references
      def validate_simple_type_references(simple_types, schema)
        schema_namespace = schema.target_namespace

        simple_types.each do |st|
          next unless st.restriction&.base
          next if builtin_type?(st.restriction.base)

          # Qualify unprefixed types with schema's namespace
          qualified_type = qualify_type_reference(st.restriction.base,
                                                  schema_namespace)
          result = repository.find_type(qualified_type)
          next if result&.resolved?

          @errors << "Unresolved base type: #{st.restriction.base} " \
                     "in simpleType #{st.name} " \
                     "(#{schema_location(schema)})"
        end
      end

      # Check element references within complex types
      def check_element_refs_in_complex_type(complex_type, schema)
        # Check sequences
        [complex_type.sequence].flatten.compact.each do |seq|
          check_element_refs_in_group_content(seq, schema)
        end

        # Check choices
        [complex_type.choice].flatten.compact.each do |choice|
          check_element_refs_in_group_content(choice, schema)
        end

        # Check all
        [complex_type.all].flatten.compact.each do |all_group|
          check_element_refs_in_group_content(all_group, schema)
        end

        # Check extension content
        return unless complex_type.complex_content&.extension

        ext = complex_type.complex_content.extension
        [ext.sequence, ext.choice, ext.all].flatten.compact.each do |content|
          check_element_refs_in_group_content(content, schema)
        end
      end

      # Check element references in group content (sequence/choice/all)
      def check_element_refs_in_group_content(content, schema)
        return unless content.element

        content.element.each do |elem|
          next unless elem.ref

          result = repository.find_element(elem.ref)
          unless result
            @errors << "Unresolved element reference: #{elem.ref} " \
                       "(#{schema_location(schema)})"
          end
        end

        # Recursively check nested groups
        [content.choice].flatten.compact.each do |nested|
          check_element_refs_in_group_content(nested, schema)
        end

        [content.sequence].flatten.compact.each do |nested|
          check_element_refs_in_group_content(nested, schema)
        end
      end

      # Validate element references
      def validate_element_references
        all_schemas.each do |schema|
          # Check group references in complex types
          schema.complex_type.each do |ct|
            check_group_refs_in_complex_type(ct, schema)
          end
        end
      end

      # Check group references in complex types
      def check_group_refs_in_complex_type(complex_type, schema)
        # Check sequences
        [complex_type.sequence].flatten.compact.each do |seq|
          check_group_refs_in_content(seq, schema)
        end

        # Check choices
        [complex_type.choice].flatten.compact.each do |choice|
          check_group_refs_in_content(choice, schema)
        end
      end

      # Check group references in content
      def check_group_refs_in_content(content, schema)
        return unless content.group

        [content.group].flatten.compact.each do |grp|
          next unless grp.ref

          result = repository.find_group(grp.ref)
          unless result
            @errors << "Unresolved group reference: #{grp.ref} " \
                       "(#{schema_location(schema)})"
          end
        end
      end

      # Validate attribute references
      def validate_attribute_references
        all_schemas.each do |schema|
          schema.complex_type.each do |ct|
            check_attribute_refs_in_complex_type(ct, schema)
          end
        end
      end

      # Check attribute references in complex types
      def check_attribute_refs_in_complex_type(complex_type, schema)
        # Check direct attributes
        [complex_type.attribute].flatten.compact.each do |attr|
          next unless attr.ref

          result = repository.find_attribute(attr.ref)
          next if result

          @errors << "Unresolved attribute reference: #{attr.ref} " \
                     "in complexType #{complex_type.name} " \
                     "(#{schema_location(schema)})"
        end

        # Check attributes in extensions
        if complex_type.complex_content&.extension
          ext = complex_type.complex_content.extension
          [ext.attribute].flatten.compact.each do |attr|
            next unless attr.ref

            result = repository.find_attribute(attr.ref)
            unless result
              @errors << "Unresolved attribute reference: #{attr.ref} " \
                         "(#{schema_location(schema)})"
            end
          end
        end

        # Check attributes in simple content
        return unless complex_type.simple_content&.extension

        ext = complex_type.simple_content.extension
        [ext.attribute].flatten.compact.each do |attr|
          next unless attr.ref

          result = repository.find_attribute(attr.ref)
          unless result
            @errors << "Unresolved attribute reference: #{attr.ref} " \
                       "(#{schema_location(schema)})"
          end
        end
      end

      # Validate group references
      def validate_group_references
        all_schemas.each do |schema|
          schema.group.each do |grp|
            # Groups can contain sequences, choices with element refs
            next unless grp.sequence || grp.choice || grp.all

            [grp.sequence, grp.choice,
             grp.all].flatten.compact.each do |content|
              check_element_refs_in_group_content(content, schema)
            end
          end
        end
      end

      # Validate attribute group references
      def validate_attribute_group_references
        all_schemas.each do |schema|
          schema.complex_type.each do |ct|
            check_attribute_group_refs_in_complex_type(ct, schema)
          end
        end
      end

      # Check attribute group references in complex types
      def check_attribute_group_refs_in_complex_type(complex_type, schema)
        schema_namespace = schema.target_namespace

        # Check direct attribute groups
        [complex_type.attribute_group].flatten.compact.each do |ag|
          next unless ag.ref

          # Qualify unprefixed attribute group references with schema's namespace
          qualified_ref = qualify_attribute_group_reference(ag.ref,
                                                            schema_namespace)
          result = repository.find_attribute_group(qualified_ref)
          next if result

          @errors << "Unresolved attributeGroup reference: #{ag.ref} " \
                     "in complexType #{complex_type.name} " \
                     "(#{schema_location(schema)})"
        end

        # Check in extensions
        return unless complex_type.complex_content&.extension

        ext = complex_type.complex_content.extension
        [ext.attribute_group].flatten.compact.each do |ag|
          next unless ag.ref

          # Qualify unprefixed attribute group references with schema's namespace
          qualified_ref = qualify_attribute_group_reference(ag.ref,
                                                            schema_namespace)
          result = repository.find_attribute_group(qualified_ref)
          unless result
            @errors << "Unresolved attributeGroup reference: #{ag.ref} " \
                       "(#{schema_location(schema)})"
          end
        end
      end

      # Validate that all imports and includes are resolved
      def validate_imports_and_includes
        all_schemas.each do |schema|
          # Check imports - import is an array of Import objects
          imports = schema.import
          imports = [imports] unless imports.is_a?(Array)

          imports.compact.each do |imp|
            next unless imp.namespace

            # Verify that the imported namespace has schemas in the repository
            found = all_schemas.any? { |s| s.target_namespace == imp.namespace }
            unless found
              @warnings << "Import namespace not found in package: #{imp.namespace} " \
                           "(#{schema_location(schema)})"
            end
          end

          # Check includes - include is an array of Include objects
          includes = schema.include
          includes = [includes] unless includes.is_a?(Array)

          includes.compact.each do |inc|
            next unless inc.schema_path

            # Verify the included schema is in the repository
            found = repository.files&.any? do |f|
              f.end_with?(File.basename(inc.schema_path))
            end
            unless found
              @warnings << "Include schema not found in package: #{inc.schema_path} " \
                           "(#{schema_location(schema)})"
            end
          end
        end
      end

      # Count type references for statistics
      def count_type_references
        count = 0
        all_schemas.each do |schema|
          count += schema.element.count { |e| e.type && !builtin_type?(e.type) }
          count += schema.attribute.count do |a|
            a.type && !builtin_type?(a.type)
          end
          count += schema.complex_type.size
          count += schema.simple_type.size
        end
        count
      end

      # Count element references for statistics
      def count_element_references
        count = 0
        all_schemas.each do |schema|
          schema.complex_type.each do |ct|
            count += count_elements_in_complex_type(ct)
          end
        end
        count
      end

      # Count elements in a complex type
      def count_elements_in_complex_type(ct)
        count = 0
        [ct.sequence, ct.choice, ct.all].flatten.compact.each do |content|
          count += count_elements_in_content(content)
        end
        count
      end

      # Count elements in content
      def count_elements_in_content(content)
        return 0 unless content.element

        count = content.element.count(&:ref)
        # Recursively count nested groups
        [content.choice].flatten.compact.each do |nested|
          count += count_elements_in_content(nested)
        end
        [content.sequence].flatten.compact.each do |nested|
          count += count_elements_in_content(nested)
        end
        count
      end

      # Count attribute references for statistics
      def count_attribute_references
        count = 0
        all_schemas.each do |schema|
          schema.complex_type.each do |ct|
            count += [ct.attribute].flatten.compact.count(&:ref)
          end
        end
        count
      end

      # Count group references for statistics
      def count_group_references
        count = 0
        all_schemas.each do |schema|
          schema.complex_type.each do |ct|
            [ct.sequence, ct.choice].flatten.compact.each do |content|
              count += [content.group].flatten.compact.count(&:ref) if content.group
            end
          end
        end
        count
      end

      # Count attribute group references for statistics
      def count_attribute_group_references
        count = 0
        all_schemas.each do |schema|
          schema.complex_type.each do |ct|
            count += [ct.attribute_group].flatten.compact.count(&:ref)
          end
        end
        count
      end

      # Get all schemas from the repository
      def all_schemas
        # Use the repository's method to get all processed schemas
        repository.all_schemas.values
      rescue StandardError
        # Fallback to parsed_schemas if the method doesn't work
        store = repository.instance_variable_get(:@parsed_schemas)
        store ? store.all.values : []
      end

      # Check if a type is a built-in XML Schema type
      def builtin_type?(type)
        return false unless type

        type.start_with?("xs:", "xsd:", "xsi:")
      end

      # Qualify an unprefixed type reference with the schema's namespace
      # @param type_ref [String] The type reference (may be prefixed or unprefixed)
      # @param schema_namespace [String, nil] The schema's target namespace
      # @return [String] The qualified type reference
      def qualify_type_reference(type_ref, schema_namespace)
        # If already prefixed or no namespace, return as-is
        return type_ref if type_ref.include?(":") || schema_namespace.nil?

        # Get prefix for this namespace
        prefix = repository.namespace_to_prefix(schema_namespace)

        # If we have a prefix, qualify the type
        prefix ? "#{prefix}:#{type_ref}" : type_ref
      end

      # Qualify an unprefixed attribute group reference with the schema's namespace
      # @param ref [String] The attribute group reference (may be prefixed or unprefixed)
      # @param schema_namespace [String, nil] The schema's target namespace
      # @return [String] The qualified attribute group reference
      def qualify_attribute_group_reference(ref, schema_namespace)
        # If already prefixed or no namespace, return as-is
        return ref if ref.include?(":") || schema_namespace.nil?

        # Get prefix for this namespace
        prefix = repository.namespace_to_prefix(schema_namespace)

        # If we have a prefix, qualify the reference
        prefix ? "#{prefix}:#{ref}" : ref
      end

      # Get a readable location for a schema
      def schema_location(schema)
        schema.instance_variable_get(:@location) || "unknown location"
      end
    end
  end
end
