# frozen_string_literal: true

require_relative "../diagram"

module Lutaml
  module Ea
    module Diagram
      # API for extracting and rendering UML diagrams from repositories
      #
      # This class provides programmatic access to diagram extraction and
      # rendering functionality. It follows API-first architecture, with
      # all business logic in this class rather than in CLI layer.
      #
      # @example Extract single diagram
      #   extractor = DiagramExtractor.new
      #   result = extractor.extract_one(
      #     "model.lur",
      #     "diagram001",
      #     output: "diagram.svg"
      #   )
      #
      # @example List all diagrams
      #   diagrams = extractor.list_diagrams("model.lur")
      #   diagrams.each { |d| puts "#{d[:name]} (#{d[:type]})" }
      #
      # @example Batch extraction
      #   results = extractor.extract_batch(
      #     "model.lur",
      #     ["dia1", "dia2", "dia3"],
      #     output_dir: "diagrams/"
      #   )
      class Extractor
        # Default rendering options
        DEFAULT_OPTIONS = {
          format: "svg",
          padding: 20,
          background_color: "#ffffff",
          grid_visible: false,
          interactive: false,
          config_path: nil
        }.freeze

        attr_reader :options

        # Initialize extractor with options
        #
        # @param options [Hash] Extraction options
        # @option options [Integer] :padding Padding around diagram
        # @option options [String] :background_color Background color
        # @option options [Boolean] :grid_visible Show grid lines
        # @option options [Boolean] :interactive Enable interactivity
        # @option options [String] :config_path Path to diagram config
        def initialize(options = {})
          @options = resolve_options(options)
        end

        # Extract and render a single diagram
        #
        # @param lur_path [String] Path to LUR repository file
        # @param diagram_id [String] Diagram ID or name
        # @param opts [Hash] Additional options
        # @option opts [String] :output Output file path
        # @return [Hash] Result with :success, :path, :diagram, :message
        def extract_one(lur_path, diagram_id, opts = {})
          merged_opts = @options.merge(opts)

          # Load repository
          repository = load_repository(lur_path)

          # Find diagram
          diagram = find_diagram(repository, diagram_id)
          unless diagram
            return {
              success: false,
              message: "Diagram not found: #{diagram_id}",
              available: repository.all_diagrams.map(&:name)
            }
          end

          # Convert to rendering format
          diagram_data = convert_to_rendering_format(diagram, repository)

          # Render
          svg_content = render_diagram(diagram_data, merged_opts)

          # Determine output path
          output_path = merged_opts[:output]

          # Write file if output path specified
          File.write(output_path, svg_content) if output_path

          result = {
            success: true,
            diagram: diagram_info(diagram),
            format: merged_opts[:format],
            message: "Diagram rendered successfully"
          }

          # Include path if file was written
          result[:path] = output_path if output_path

          # Include SVG content if no output file (for testing)
          result[:svg_content] = svg_content unless output_path

          result
        rescue StandardError => e
          {
            success: false,
            message: "Failed to extract diagram: #{e.message}",
            error: e
          }
        end

        # List all diagrams in repository
        #
        # @param lur_path [String] Path to LUR repository file
        # @return [Hash] Result with :success, :diagrams, :count, :message
        def list_diagrams(lur_path)
          repository = load_repository(lur_path)
          diagrams = repository.all_diagrams

          {
            success: true,
            count: diagrams.size,
            diagrams: diagrams.map { |d| diagram_info(d) }
          }
        rescue StandardError => e
          {
            success: false,
            message: "Failed to list diagrams: #{e.message}",
            error: e
          }
        end

        # Extract multiple diagrams in batch
        #
        # @param lur_path [String] Path to LUR repository file
        # @param diagram_ids [Array<String>] Array of diagram IDs
        # @param opts [Hash] Additional options
        # @option opts [String] :output_dir Output directory
        # @return [Hash] Result with :success, :results, :summary
        def extract_batch(lur_path, diagram_ids, opts = {})
          merged_opts = @options.merge(opts)
          output_dir = merged_opts[:output_dir] || "."

          # Create output directory if needed
          FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

          results = diagram_ids.map do |diagram_id|
            output_path = File.join(output_dir, "#{sanitize_filename(diagram_id)}.svg")
            extract_one(lur_path, diagram_id, merged_opts.merge(output: output_path))
          end

          successful = results.count { |r| r[:success] }
          failed = results.count { |r| !r[:success] }

          {
            success: failed == 0,
            results: results,
            summary: {
              total: diagram_ids.size,
              successful: successful,
              failed: failed
            }
          }
        rescue StandardError => e
          {
            success: false,
            message: "Batch extraction failed: #{e.message}",
            error: e
          }
        end

        private

        # Resolve options from defaults, environment, and parameters
        def resolve_options(opts)
          resolved = DEFAULT_OPTIONS.dup

          # Environment variables
          resolved[:padding] = ENV["LUTAML_DIAGRAM_PADDING"].to_i if ENV["LUTAML_DIAGRAM_PADDING"]
          resolved[:background_color] = ENV["LUTAML_DIAGRAM_BG_COLOR"] if ENV["LUTAML_DIAGRAM_BG_COLOR"]
          resolved[:grid_visible] = ENV["LUTAML_DIAGRAM_GRID"] == "true" if ENV["LUTAML_DIAGRAM_GRID"]
          resolved[:interactive] = ENV["LUTAML_DIAGRAM_INTERACTIVE"] == "true" if ENV["LUTAML_DIAGRAM_INTERACTIVE"]
          resolved[:config_path] = ENV["LUTAML_DIAGRAM_CONFIG"] if ENV["LUTAML_DIAGRAM_CONFIG"]

          # User-provided options override environment
          resolved.merge(opts)
        end

        # Load repository from LUR file
        def load_repository(lur_path)
          raise "File not found: #{lur_path}" unless File.exist?(lur_path)

          Lutaml::UmlRepository::Repository.from_package(lur_path)
        end

        # Find diagram by ID or name
        def find_diagram(repository, diagram_id)
          # Try exact match by XMI ID first
          diagram = repository.find_diagram(diagram_id)
          return diagram if diagram

          # Try partial name match (case-insensitive)
          all_diagrams = repository.all_diagrams
          all_diagrams.find { |d| d.name.downcase.include?(diagram_id.downcase) }
        end

        # Convert diagram to rendering format
        def convert_to_rendering_format(diagram, repository)
          elements = build_elements(diagram, repository)
          connectors = build_connectors(diagram, repository)

          {
            name: diagram.name,
            elements: elements,
            connectors: connectors
          }
        end

        # Build element data from diagram objects
        def build_elements(diagram, repository)
          diagram.diagram_objects.map do |obj|
            uml_element = find_element(obj.object_xmi_id, repository)
            next unless uml_element

            element_data = {
              id: obj.diagram_object_id || obj.object_xmi_id,
              type: element_type(uml_element),
              name: uml_element.name,
              x: obj.left || 0,
              y: obj.top || 0,
              width: (obj.right - obj.left) || 120,
              height: (obj.bottom - obj.top) || 80,
              style: obj.style
            }

            # Add stereotype
            if uml_element.respond_to?(:stereotype) && uml_element.stereotype
              element_data[:stereotype] = array_value(uml_element.stereotype).first
            end

            # Add class-specific data
            add_class_data(element_data, uml_element) if element_data[:type] == "class"

            element_data
          end.compact
        end

        # Build connector data from diagram links
        def build_connectors(diagram, repository)
          diagram.diagram_links.map do |link|
            connector = find_connector(link.connector_xmi_id, repository)
            next unless connector

            source_obj = find_diagram_object(connector.source.xmi_id, diagram) if connector.respond_to?(:source) && connector.source
            target_obj = find_diagram_object(connector.target.xmi_id, diagram) if connector.respond_to?(:target) && connector.target

            connector_data = {
              id: link.connector_id || link.connector_xmi_id,
              type: connector_type(connector),
              element: connector,
              diagram_link: link,
              style: link.style,
              geometry: link.geometry,
              path: link.path
            }

            # Add source/target positions
            if source_obj
              connector_data[:source_element] = {
                left: source_obj.left,
                top: source_obj.top,
                right: source_obj.right,
                bottom: source_obj.bottom
              }
            end

            if target_obj
              connector_data[:target_element] = {
                left: target_obj.left,
                top: target_obj.top,
                right: target_obj.right,
                bottom: target_obj.bottom
              }
            end

            # Add role and multiplicity
            add_connector_metadata(connector_data, connector)

            connector_data
          end.compact
        end

        # Add class attributes and operations
        def add_class_data(element_data, uml_element)
          if uml_element.respond_to?(:attributes) && uml_element.attributes
            element_data[:attributes] = uml_element.attributes.map do |attr|
              {
                name: attr.name,
                type: attr.type,
                visibility: attr.visibility || "public"
              }
            end
          end

          if uml_element.respond_to?(:operations) && uml_element.operations
            element_data[:operations] = uml_element.operations.map do |op|
              {
                name: op.name,
                return_type: op.return_type,
                visibility: op.visibility || "public",
                parameters: op.parameters&.map { |p| { name: p.name, type: p.type } } || []
              }
            end
          end
        end

        # Add connector role and multiplicity information
        def add_connector_metadata(connector_data, connector)
          connector_data[:source_role] = connector.owner_end_attribute_name if connector.respond_to?(:owner_end_attribute_name)
          connector_data[:target_role] = connector.member_end_attribute_name if connector.respond_to?(:member_end_attribute_name)

          if connector.respond_to?(:owner_end_cardinality) && connector.owner_end_cardinality
            connector_data[:source_multiplicity] = format_cardinality(connector.owner_end_cardinality)
          end

          if connector.respond_to?(:member_end_cardinality) && connector.member_end_cardinality
            connector_data[:target_multiplicity] = format_cardinality(connector.member_end_cardinality)
          end
        end

        # Find UML element by XMI ID
        def find_element(xmi_id, repository)
          repository.classes_index.find { |c| c.xmi_id == xmi_id } ||
            repository.packages_index.find { |p| p.xmi_id == xmi_id } ||
            repository.data_types_index.find { |d| d.xmi_id == xmi_id } ||
            repository.enums_index.find { |e| e.xmi_id == xmi_id }
        end

        # Find connector by XMI ID
        def find_connector(xmi_id, repository)
          repository.associations_index.find { |a| a.xmi_id == xmi_id }
        end

        # Find diagram object for element
        def find_diagram_object(element_xmi_id, diagram)
          diagram.diagram_objects.find { |obj| obj.object_xmi_id == element_xmi_id }
        end

        # Determine element type from UML class
        def element_type(uml_element)
          case uml_element
          when Lutaml::Uml::Class then "class"
          when Lutaml::Uml::Package then "package"
          when Lutaml::Uml::DataType then "datatype"
          when Lutaml::Uml::Enum then "enumeration"
          else "unknown"
          end
        end

        # Determine connector type
        def connector_type(connector)
          case connector
          when Lutaml::Uml::Association then "association"
          when Lutaml::Uml::Generalization then "generalization"
          when Lutaml::Uml::Dependency then "dependency"
          else "connector"
          end
        end

        # Render diagram to SVG
        def render_diagram(diagram_data, opts)
          Lutaml::Ea::Diagram.render(diagram_data, opts)
        end

        # Get diagram information
        def diagram_info(diagram)
          {
            xmi_id: diagram.xmi_id,
            name: diagram.name,
            type: diagram.diagram_type,
            package: diagram.package_name || "Unknown",
            objects: diagram.diagram_objects&.size || 0,
            links: diagram.diagram_links&.size || 0
          }
        end

        # Default output path for diagram
        def default_output_path(diagram)
          "#{sanitize_filename(diagram.name)}.svg"
        end

        # Sanitize filename
        def sanitize_filename(name)
          name.gsub(/[^a-zA-Z0-9_-]/, "_")
        end

        # Format cardinality for display
        def format_cardinality(cardinality)
          cardinality.respond_to?(:to_s) ? cardinality.to_s : ""
        end

        # Convert value to array
        def array_value(value)
          value.is_a?(Array) ? value : [value]
        end
      end
    end
  end
end