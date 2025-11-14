# frozen_string_literal: true

require "csv"
require_relative "base_exporter"

module Lutaml
  module UmlRepository
    module Exporters
      # Export UML classes to CSV format.
      #
      # Exports a tabular representation of classes with their metadata
      # including qualified name, stereotype, attribute count, association
      # count, and package.
      #
      # @example Basic export
      #   exporter = CsvExporter.new(repository)
      #   exporter.export("classes.csv")
      #
      # @example Export with filters
      #   exporter.export("classes.csv",
      #     package: "ModelRoot::i-UR::urf",
      #     stereotype: "featureType"
      #   )
      #
      # @example Include attributes as separate rows
      #   exporter.export("classes.csv", include_attributes: true)
      class CsvExporter < BaseExporter
        # Export classes to CSV format.
        #
        # @param output_path [String] Path to the output CSV file
        # @param options [Hash] Export options
        # @option options [String] :package Filter by package path
        # @option options [String] :stereotype Filter by stereotype
        # @option options [Boolean] :include_attributes (false) Include
        #   attributes as separate rows
        # @option options [Boolean] :recursive (false) Include classes from
        #   nested packages when filtering by package
        # @return [void]
        def export(output_path, options = {})
          classes = collect_classes(options)

          CSV.open(output_path, "w") do |csv|
            csv << headers(options)

            if options[:include_attributes]
              export_with_attributes(csv, classes)
            else
              export_classes_only(csv, classes)
            end
          end
        end

        private

        # Collect classes based on filter options.
        #
        # @param options [Hash] Filter options
        # @return [Array] Array of class objects
        def collect_classes(options)
          classes = if options[:package]
                      repository.classes_in_package(
                        options[:package],
                        recursive: options[:recursive] || false,
                      )
                    else
                      indexes[:classes].values
                    end

          if options[:stereotype]
            classes = filter_by_stereotype(classes,
                                           options[:stereotype])
          end
          classes.sort_by { |klass| qualified_name(klass) }
        end

        # Filter classes by stereotype.
        #
        # @param classes [Array] Array of class objects
        # @param stereotype [String] Stereotype to filter by
        # @return [Array] Filtered array of classes
        def filter_by_stereotype(classes, stereotype)
          classes.select do |klass|
            klass.stereotypes&.include?(stereotype)
          end
        end

        # Get CSV headers.
        #
        # @param options [Hash] Export options
        # @return [Array<String>] Array of header strings
        def headers(options)
          base_headers = [
            "Qualified Name",
            "Name",
            "Stereotype",
            "Attributes Count",
            "Associations Count",
            "Package",
          ]

          if options[:include_attributes]
            base_headers + ["Attribute Name", "Attribute Type"]
          else
            base_headers
          end
        end

        # Export classes without attribute details.
        #
        # @param csv [CSV] The CSV writer object
        # @param classes [Array] Array of class objects
        # @return [void]
        def export_classes_only(csv, classes)
          classes.each do |klass|
            csv << format_class_row(klass)
          end
        end

        # Export classes with attributes as separate rows.
        #
        # @param csv [CSV] The CSV writer object
        # @param classes [Array] Array of class objects
        # @return [void]
        def export_with_attributes(csv, classes)
          classes.each do |klass|
            base_row = format_class_row(klass)

            if klass.attributes&.any?
              klass.attributes.each do |attr|
                csv << (base_row + [attr.name, attr.type || ""])
              end
            else
              csv << (base_row + ["", ""])
            end
          end
        end

        # Format a class as a CSV row.
        #
        # @param klass [Lutaml::Uml::Class, Lutaml::Uml::DataType,
        #   Lutaml::Uml::Enum] The class object
        # @return [Array] Array of values for the row
        def format_class_row(klass)
          qname = qualified_name(klass)
          package_path = extract_package_path(qname)
          stereotypes = klass.stereotypes&.join(", ") || ""
          attrs_count = klass.attributes&.size || 0
          assocs_count = count_associations(klass)

          [
            qname,
            klass.name,
            stereotypes,
            attrs_count,
            assocs_count,
            package_path,
          ]
        end

        # Get the qualified name of a class.
        #
        # @param klass [Object] The class object
        # @return [String] The qualified name
        def qualified_name(klass)
          indexes[:class_to_qname][klass.xmi_id] || klass.name
        end

        # Extract package path from qualified name.
        #
        # @param qname [String] The qualified name
        # @return [String] The package path
        def extract_package_path(qname)
          parts = qname.split("::")
          parts.size > 1 ? parts[0..-2].join("::") : ""
        end

        # Count associations involving a class.
        #
        # @param klass [Object] The class object
        # @return [Integer] Count of associations
        def count_associations(klass)
          repository.associations_of(klass).size
        rescue StandardError
          0
        end
      end
    end
  end
end
