# frozen_string_literal: true

require "json"
require_relative "base_exporter"

module Lutaml
  module UmlRepository
    module Exporters
      # Export UML repository to JSON format.
      #
      # Exports the complete UML model as JSON, preserving all relationships
      # and metadata. Supports filtering by package and optional pretty
      # printing.
      #
      # @example Basic export
      #   exporter = JsonExporter.new(repository)
      #   exporter.export("model.json")
      #
      # @example Pretty-printed export
      #   exporter.export("model.json", pretty: true)
      #
      # @example Export specific package
      #   exporter.export("model.json", package: "ModelRoot::i-UR::urf")
      class JsonExporter < BaseExporter
        # Export repository to JSON format.
        #
        # @param output_path [String] Path to the output JSON file
        # @param options [Hash] Export options
        # @option options [Boolean] :pretty (true) Pretty-print JSON
        # @option options [String] :package Filter by package path
        # @option options [Boolean] :recursive (false) Include nested packages
        #   when filtering
        # @option options [Boolean] :include_diagrams (true) Include diagram
        #   metadata
        # @return [void]
        def export(output_path, options = {})
          data = build_export_data(options)

          File.write(output_path, format_json(data, options))
        end

        private

        # Build the export data structure.
        #
        # @param options [Hash] Export options
        # @return [Hash] The complete data structure
        def build_export_data(options)
          {
            metadata: build_metadata,
            packages: build_packages(options),
            classes: build_classes(options),
            associations: build_associations(options),
            diagrams: if options.fetch(:include_diagrams,
                                       true)
                        build_diagrams(options)
                      else
                        []
                      end,
          }
        end

        # Build metadata section.
        #
        # @return [Hash] Metadata hash
        def build_metadata
          stats = repository.statistics
          {
            exported_at: Time.now.utc.iso8601,
            total_packages: stats&.dig(:total_packages) || 0,
            total_classes: stats&.dig(:total_classes) || 0,
            total_associations: stats&.dig(:total_associations) || 0,
            total_diagrams: stats&.dig(:total_diagrams) || 0,
          }
        end

        # Build packages section.
        #
        # @param options [Hash] Export options
        # @return [Array<Hash>] Array of package hashes
        def build_packages(options)
          packages = if options[:package]
                       repository.list_packages(
                         options[:package],
                         recursive: options[:recursive] || false,
                       )
                     else
                       repository.list_packages("ModelRoot", recursive: true)
                     end

          packages.map { |pkg| serialize_package(pkg) }
        end

        # Serialize a package to a hash.
        #
        # @param package [Lutaml::Uml::Package, Lutaml::Uml::Document]
        #   The package object
        # @return [Hash] Package data
        def serialize_package(package)
          {
            id: package.xmi_id,
            name: package.name,
            path: package_path(package),
            classes_count: package.classes&.size || 0,
            packages_count: package.packages&.size || 0,
          }
        end

        # Get package path.
        #
        # @param package [Object] The package object
        # @return [String] The package path
        def package_path(package)
          indexes&.dig(:package_to_path, package.xmi_id) || package.name
        end

        # Build classes section.
        #
        # @param options [Hash] Export options
        # @return [Array<Hash>] Array of class hashes
        def build_classes(options)
          classes = if options[:package]
                      repository.classes_in_package(
                        options[:package],
                        recursive: options[:recursive] || false,
                      )
                    else
                      indexes&.dig(:classes)&.values || []
                    end

          classes.map { |klass| serialize_class(klass) }
        end

        # Serialize a class to a hash.
        #
        # @param klass [Lutaml::Uml::Class, Lutaml::Uml::DataType,
        #   Lutaml::Uml::Enum] The class object
        # @return [Hash] Class data
        def serialize_class(klass)
          qname = qualified_name(klass)

          {
            id: klass.xmi_id,
            qualified_name: qname,
            name: klass.name,
            type: class_type(klass),
            stereotypes: normalize_stereotypes(klass.stereotype),
            package: extract_package_path(qname),
            attributes: serialize_attributes(klass),
            operations: serialize_operations(klass),
            generalizations: serialize_generalizations(klass),
          }
        end

        # Normalize stereotypes to array format.
        #
        # @param stereotype [String, Array, nil] The stereotype(s)
        # @return [Array] Array of stereotypes
        def normalize_stereotypes(stereotype)
          return [] unless stereotype

          case stereotype
          when Array
            stereotype
          when String
            [stereotype]
          else
            []
          end
        end

        # Get class type.
        #
        # @param klass [Object] The class object
        # @return [String] The class type
        def class_type(klass)
          klass.class.name.split("::").last
        end

        # Get qualified name.
        #
        # @param klass [Object] The class object
        # @return [String] The qualified name
        def qualified_name(klass)
          indexes&.dig(:class_to_qname, klass.xmi_id) || klass.name
        end

        # Extract package path from qualified name.
        #
        # @param qname [String] The qualified name
        # @return [String] The package path
        def extract_package_path(qname)
          parts = qname.split("::")
          parts.size > 1 ? parts[0..-2].join("::") : ""
        end

        # Serialize class attributes.
        #
        # @param klass [Object] The class object
        # @return [Array<Hash>] Array of attribute hashes
        def serialize_attributes(klass)
          return [] unless klass.attributes

          klass.attributes.map do |attr|
            {
              name: attr.name,
              type: attr.type,
              visibility: attr.visibility,
              cardinality: serialize_cardinality(attr.cardinality),
            }
          end
        end

        # Serialize cardinality.
        #
        # @param cardinality [Lutaml::Uml::Cardinality, nil] The cardinality
        # @return [Hash, nil] Cardinality data
        def serialize_cardinality(cardinality)
          return nil unless cardinality

          {
            min: cardinality.min,
            max: cardinality.max,
          }
        end

        # Serialize class operations.
        #
        # @param klass [Object] The class object
        # @return [Array<Hash>] Array of operation hashes
        def serialize_operations(klass)
          return [] unless klass.respond_to?(:operations) && klass.operations

          klass.operations.map do |op|
            {
              name: op.name,
              visibility: op.visibility,
              return_type: op.return_type,
            }
          end
        end

        # Serialize generalizations.
        #
        # @param klass [Object] The class object
        # @return [Array<String>] Array of parent class qualified names
        def serialize_generalizations(klass)
          parent = repository.supertype_of(klass)
          parent ? [qualified_name(parent)] : []
        rescue StandardError
          []
        end

        # Build associations section.
        #
        # @param options [Hash] Export options
        # @return [Array<Hash>] Array of association hashes
        def build_associations(options)
          associations = indexes[:associations]&.values || []

          # Filter by package if specified
          if options[:package]
            classes = repository.classes_in_package(
              options[:package],
              recursive: options[:recursive] || false,
            )
            class_ids = classes.to_set(&:xmi_id)
            associations = associations.select do |assoc|
              class_ids.include?(assoc.member_end_xmi_id) ||
                class_ids.include?(assoc.owner_end_xmi_id)
            end
          end

          associations.map { |assoc| serialize_association(assoc) }
        end

        # Serialize an association.
        #
        # @param association [Lutaml::Uml::Association] The association object
        # @return [Hash] Association data
        def serialize_association(association)
          {
            id: association.xmi_id,
            name: association.name,
            owner_end: association.owner_end,
            owner_end_attribute_name: association.owner_end_attribute_name,
            owner_end_cardinality: serialize_cardinality(association.owner_end_cardinality),
            owner_end_type: association.owner_end_type,
            owner_end_xmi_id: association.owner_end_xmi_id,
            member_end: association.member_end,
            member_end_attribute_name: association.member_end_attribute_name,
            member_end_xmi_id: association.member_end_xmi_id,
            member_end_cardinality: serialize_cardinality(association.member_end_cardinality),
            member_end_type: association.member_end_type,
          }
        end

        # Build diagrams section.
        #
        # @param options [Hash] Export options
        # @return [Array<Hash>] Array of diagram hashes
        def build_diagrams(options)
          diagrams = if options[:package]
                       repository.diagrams_in_package(options[:package])
                     else
                       repository.all_diagrams
                     end

          diagrams.map { |diagram| serialize_diagram(diagram) }
        rescue StandardError
          []
        end

        # Serialize a diagram.
        #
        # @param diagram [Lutaml::Uml::Diagram] The diagram object
        # @return [Hash] Diagram data
        def serialize_diagram(diagram)
          {
            id: diagram.xmi_id,
            name: diagram.name,
            type: diagram.diagram_type,
          }
        end

        # Format JSON output.
        #
        # @param data [Hash] The data to format
        # @param options [Hash] Formatting options
        # @return [String] Formatted JSON string
        def format_json(data, options)
          if options.fetch(:pretty, true)
            JSON.pretty_generate(data)
          else
            JSON.generate(data)
          end
        end
      end
    end
  end
end
