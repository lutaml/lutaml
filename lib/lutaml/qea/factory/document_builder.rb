# frozen_string_literal: true

require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Builds and validates UML Document structure
      # Ensures all required document sections are populated correctly
      class DocumentBuilder
        attr_reader :document

        # Initialize builder with new document
        # @param name [String] Document name
        def initialize(name: "EA Model")
          @document = Lutaml::Uml::Document.new
          @document.name = name
          # Don't initialize collections - they have default values
        end

        # Add packages to document
        # @param packages [Array<Lutaml::Uml::Package>] Packages to add
        # @return [self] For method chaining
        def add_packages(packages)
          return self if packages.nil? || packages.empty?

          @document.packages.concat(packages)
          self
        end

        # Add classes to document
        # @param classes [Array<Lutaml::Uml::Class>] Classes to add
        # @return [self] For method chaining
        def add_classes(classes)
          return self if classes.nil? || classes.empty?

          @document.classes.concat(classes)
          self
        end

        # Add enums to document
        # @param enums [Array<Lutaml::Uml::Enum>] Enums to add
        # @return [self] For method chaining
        def add_enums(enums)
          return self if enums.nil? || enums.empty?

          @document.enums.concat(enums)
          self
        end

        # Add data types to document
        # @param data_types [Array<Lutaml::Uml::DataType>] Data types to add
        # @return [self] For method chaining
        def add_data_types(data_types)
          return self if data_types.nil? || data_types.empty?

          @document.data_types.concat(data_types)
          self
        end

        # Add instances to document
        # @param instances [Array<Lutaml::Uml::Instance>] Instances to add
        # @return [self] For method chaining
        def add_instances(instances)
          return self if instances.nil? || instances.empty?

          @document.instances.concat(instances)
          self
        end

        # Add associations to document
        # @param associations [Array<Lutaml::Uml::Association>] Associations
        # @return [self] For method chaining
        def add_associations(associations)
          return self if associations.nil? || associations.empty?

          @document.associations.concat(associations)
          self
        end

        # Set document metadata
        # @param title [String] Document title
        # @param caption [String] Document caption
        # @return [self] For method chaining
        def set_metadata(title: nil, caption: nil)
          @document.title = title if title
          @document.caption = caption if caption
          self
        end

        # Build and return the document
        # @param validate [Boolean] Whether to validate before returning
        # @return [Lutaml::Uml::Document] The built document
        # @raise [ValidationError] If validation fails
        def build(validate: true)
          validate! if validate
          @document
        end

        # Validate document integrity
        # @return [Boolean] True if valid
        # @raise [ValidationError] If validation fails
        def validate! # rubocop:disable Metrics/MethodLength
          errors = []
          warnings = []

          # Check for duplicate xmi_ids
          check_duplicate_xmi_ids(errors)

          # Check association references (warnings only for missing refs)
          check_association_references(warnings)

          # Print warnings if any
          unless warnings.empty?
            warn "Document validation warnings:"
            warnings.each { |w| warn "  - #{w}" }
          end

          raise ValidationError, errors.join("; ") unless errors.empty?

          true
        end

        # Get document statistics
        # @return [Hash] Statistics about document contents
        def stats
          {
            packages: @document.packages.size,
            classes: @document.classes.size,
            enums: @document.enums.size,
            data_types: @document.data_types.size,
            instances: @document.instances.size,
            associations: @document.associations.size,
          }
        end

        private

        # Check for duplicate xmi_ids across all elements
        # @param errors [Array<String>] Error accumulator
        def check_duplicate_xmi_ids(errors)
          xmi_ids = collect_all_xmi_ids
          duplicates = xmi_ids.group_by { |id| id }
            .select { |_, v| v.size > 1 }
            .keys

          unless duplicates.empty?
            errors << "Duplicate xmi_ids found: #{duplicates.join(', ')}"
          end
        end

        # Collect all xmi_ids from document
        # @return [Array<String>] All xmi_ids
        def collect_all_xmi_ids # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          ids = []

          # Collect from top-level elements
          ids.concat(@document.packages.filter_map(&:xmi_id))
          ids.concat(@document.classes.filter_map(&:xmi_id))
          ids.concat(@document.enums.filter_map(&:xmi_id))
          ids.concat(@document.data_types.filter_map(&:xmi_id))
          ids.concat(@document.instances.filter_map(&:xmi_id))

          # Recursively collect from packages (where most classes actually are)
          @document.packages.each do |package|
            ids.concat(collect_package_xmi_ids(package))
          end

          ids
        end

        # Recursively collect all xmi_ids from a package and its descendants
        # @param package [Lutaml::Uml::Package] Package to collect from
        # @return [Array<String>] All xmi_ids in package hierarchy
        def collect_package_xmi_ids(package) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          ids = []

          # Collect from package's elements
          ids.concat(package.classes.filter_map(&:xmi_id)) if package.classes
          ids.concat(package.enums.filter_map(&:xmi_id)) if package.enums
          if package.data_types
            ids.concat(package.data_types.filter_map(&:xmi_id))
          end
          if package.instances
            ids.concat(package.instances.filter_map(&:xmi_id))
          end

          # Recursively collect from child packages
          package.packages&.each do |child_package|
            ids.concat(collect_package_xmi_ids(child_package))
          end

          ids
        end

        # Check that all association references are valid
        # @param warnings [Array<String>] Warning accumulator
        def check_association_references(warnings) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return if @document.associations.empty?

          all_xmi_ids = collect_all_xmi_ids.to_set
          invalid_associations = []

          @document.associations.each do |assoc|
            has_invalid_member = !check_association_end_valid?(
              assoc, :member_end_xmi_id, all_xmi_ids
            )
            has_invalid_owner = !check_association_end_valid?(
              assoc, :owner_end_xmi_id, all_xmi_ids
            )

            if has_invalid_member || has_invalid_owner
              invalid_associations << assoc
              if has_invalid_member
                add_invalid_end_warning(assoc, :member_end_xmi_id, all_xmi_ids,
                                        warnings)
              end
              if has_invalid_owner
                add_invalid_end_warning(assoc, :owner_end_xmi_id, all_xmi_ids,
                                        warnings)
              end
            end
          end

          # Remove invalid associations from document
          unless invalid_associations.empty?
            @document.associations.reject! do |a|
              invalid_associations.include?(a)
            end
            warnings << "Removed #{invalid_associations.size} association(s) " \
                        "with invalid references"
          end
        end

        # Check if association end reference is valid
        # @param assoc [Lutaml::Uml::Association] Association
        # @param attr [Symbol] Attribute to check (should be xmi_id attribute)
        # @param valid_ids [Set<String>] Set of valid xmi_ids
        # @return [Boolean] True if valid or nil
        def check_association_end_valid?(assoc, attr, valid_ids)
          value = assoc.send(attr)
          return true if value.nil?

          valid_ids.include?(value)
        end

        # Add warning for invalid association end
        # @param assoc [Lutaml::Uml::Association] Association
        # @param attr [Symbol] Attribute to check (should be xmi_id attribute)
        # @param valid_ids [Set<String>] Set of valid xmi_ids
        # @param warnings [Array<String>] Warning accumulator
        def add_invalid_end_warning(assoc, attr, valid_ids, warnings) # rubocop:disable Metrics/MethodLength
          value = assoc.send(attr)
          return if value.nil?

          unless valid_ids.include?(value)
            # Get the corresponding name attribute for better error messages
            name_attr = attr.to_s.gsub("_xmi_id", "").to_sym
            name_value = begin
              assoc.send(name_attr)
            rescue StandardError
              nil
            end

            warnings << "Association #{assoc.xmi_id} references " \
                        "invalid #{name_attr}: #{name_value}"
          end
        end

        # Custom validation error
        class ValidationError < Lutaml::Error; end
      end
    end
  end
end
