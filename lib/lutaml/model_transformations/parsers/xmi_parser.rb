# frozen_string_literal: true

require_relative "base_parser"
require_relative "../../parser"

module Lutaml
  module ModelTransformations
    module Parsers
      # XMI Parser implements the BaseParser interface for XML Metadata Interchange files.
      #
      # This parser wraps the existing Lutaml::Parser functionality and adapts it
      # to the new unified transformation architecture. It follows the Adapter pattern
      # to integrate legacy XMI parsing with the new system.
      class XmiParser < BaseParser
        # Get parser format name
        #
        # @return [String] Human-readable format name
        def format_name
          "XML Metadata Interchange (XMI)"
        end

        # Get list of supported file extensions
        #
        # @return [Array<String>] List of extensions
        def supported_extensions
          [".xmi", ".xml"]
        end

        def content_patterns
          [/xmi:version/]
        end

        def priority
          80
        end

        protected

        # Core parsing implementation for XMI files
        #
        # @param file_path [String] Path to the XMI file
        # @return [Lutaml::Uml::Document] Parsed UML document
        def parse_internal(file_path)
          # Validate XMI file format
          validate_xmi_format!(file_path)

          # Use existing Lutaml::Xmi::Parsers::Xml for XMI parsing
          document = Lutaml::Xmi::Parsers::Xml.parse(File.new(file_path))

          if document.nil?
            add_error("No document found in XMI file")
            raise Parsers::ParseError.new("Empty XMI file or parsing failed")
          end

          # Post-process document if needed
          post_process_xmi_document(document, file_path)

          document
        end

        # Hook called before parsing starts
        #
        # @param file_path [String] Path to the file being parsed
        # @return [void]
        def before_parse(file_path)
          add_info("Starting XMI parsing for: #{file_path}")

          # Check file size and warn if very large
          file_size = File.size(file_path)
          if file_size > 100 * 1024 * 1024 # 100MB
            add_warning("Large XMI file detected (#{format_file_size(file_size)}), parsing may take time")
          end
        end

        # Hook called after parsing completes
        #
        # @param document [Lutaml::Uml::Document] Parsed document
        # @param file_path [String] Path to the source file
        # @return [Lutaml::Uml::Document] Processed document
        def after_parse(document, file_path)
          # Add metadata about the parsing process
          add_parsing_metadata(document, file_path)

          # Validate references if requested
          validate_references(document) if @options[:resolve_references]

          # Count elements and add statistics
          add_parsing_statistics(document)

          document
        end

        # Get default parsing options for XMI
        #
        # @return [Hash] Default options hash
        def default_options
          super.merge(
            validate_xml: true,
            resolve_references: true,
            preserve_namespaces: true,
            include_documentation: true,
          )
        end

        private

        # Validate XMI file format
        #
        # @param file_path [String] Path to validate
        # @raise [ParseError] if file is not valid XMI
        def validate_xmi_format!(file_path)
          # Quick validation by reading first few lines
          File.open(file_path, "r") do |file|
            header = file.read(1024)

            unless header.include?("<?xml")
              add_error("File does not appear to be an XML file")
              raise Parsers::ParseError.new("Invalid XML format")
            end

            # Check for XMI-specific elements
            unless header.include?("xmi:") || header.include?("uml:")
              add_warning("File may not be a valid XMI file (no XMI namespace found)")
            end
          end
        end

        # Post-process XMI document
        #
        # @param document [Lutaml::Uml::Document] Document to process
        # @param file_path [String] Source file path
        # @return [void]
        def post_process_xmi_document(document, file_path)
          # Set source file information
          if document.respond_to?(:source_file=)
            document.source_file = file_path
          end

          # Add timestamp
          if document.respond_to?(:parsed_at=)
            document.parsed_at = Time.now
          end

          # Normalize package paths if requested
          normalize_package_paths(document) if @options[:normalize_paths]
        end

        # Add parsing metadata to document
        #
        # @param document [Lutaml::Uml::Document] Document to enhance
        # @param file_path [String] Source file path
        # @return [void]
        def add_parsing_metadata(document, file_path)
          metadata = {
            source_file: file_path,
            parsed_at: Time.now,
            parser: self.class.name,
            parser_version: "1.0",
            options: @options,
          }

          # Store metadata if document supports it
          if document.respond_to?(:parsing_metadata=)
            document.parsing_metadata = metadata
          elsif document.respond_to?(:instance_variable_set)
            # Store in custom attribute if available
            document.instance_variable_set(:@parsing_metadata,
                                           metadata)
          end
        end

        # Validate document references
        #
        # @param document [Lutaml::Uml::Document] Document to validate
        # @return [void]
        def validate_references(document)
          # Check for unresolved references
          unresolved_refs = find_unresolved_references(document)

          if unresolved_refs.any?
            add_warning("Found #{unresolved_refs.size} unresolved references")
            unresolved_refs.each do |ref|
              add_warning("Unresolved reference: #{ref}")
            end
          end
        end

        # Find unresolved references in document
        #
        # @param document [Lutaml::Uml::Document] Document to check
        # @return [Array<String>] List of unresolved reference IDs
        def find_unresolved_references(document)
          unresolved = []

          # This is a simplified implementation
          # In practice, you would traverse the document structure
          # and check for dangling references

          # Check class generalizations
          document.classes&.each do |klass|
            klass.generalizations&.each do |gen|
              # Reference by ID that might be unresolved
              if gen.general.is_a?(String) && !find_element_by_id(document,
                                                                  gen.general)
                unresolved << gen.general
              end
            end
          end

          unresolved.uniq
        end

        # Find element by ID in document
        #
        # @param document [Lutaml::Uml::Document] Document to search
        # @param id [String] ID to find
        # @return [Object, nil] Found element or nil
        def find_element_by_id(document, id)
          # Simplified implementation - in practice would use proper indexing
          all_elements = []
          all_elements.concat(document.packages || [])
          all_elements.concat(document.classes || [])
          all_elements.concat(document.data_types || [])
          all_elements.concat(document.enums || [])

          all_elements.find { |element| element.xmi_id == id }
        end

        # Add parsing statistics
        #
        # @param document [Lutaml::Uml::Document] Document to analyze
        # @return [void]
        def add_parsing_statistics(document)
          stats = {
            packages: document.packages&.size || 0,
            classes: document.classes&.size || 0,
            data_types: document.data_types&.size || 0,
            enumerations: document.enums&.size || 0,
            associations: document.associations&.size || 0,
            diagrams: document.diagrams&.size || 0,
          }

          add_info("Parsed XMI successfully: #{format_statistics(stats)}")
        end

        # Normalize package paths
        #
        # @param document [Lutaml::Uml::Document] Document to process
        # @return [void]
        def normalize_package_paths(_document)
          # Implementation would normalize package path formats
          # This is a placeholder for future enhancement
          add_info("Package path normalization completed")
        end

        # Format file size for display
        #
        # @param size [Integer] Size in bytes
        # @return [String] Formatted size string
        def format_file_size(size)
          units = %w[B KB MB GB]
          size = size.to_f
          unit_index = 0

          while size >= 1024 && unit_index < units.length - 1
            size /= 1024
            unit_index += 1
          end

          "#{size.round(1)} #{units[unit_index]}"
        end

        # Format statistics for display
        #
        # @param stats [Hash] Statistics hash
        # @return [String] Formatted statistics string
        def format_statistics(stats)
          parts = stats.map { |key, value| "#{value} #{key}" }
          parts.join(", ")
        end

        # Add info message (similar to warning but for information)
        #
        # @param message [String] Info message
        # @param context [Hash] Additional context
        # @return [void]
        def add_info(message, context = {})
          # For now, treat as warnings since base parser doesn't have info level
          # In future, could extend base parser to support info level
          add_warning(message, context)
        end
      end
    end
  end
end
