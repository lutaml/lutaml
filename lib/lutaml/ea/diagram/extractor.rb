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
          config_path: nil,
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
        def extract_one(lur_path, diagram_id, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          merged_opts = @options.merge(opts)

          # Load repository
          repository = load_repository(lur_path)

          # Find diagram
          diagram = find_diagram(repository, diagram_id)
          unless diagram
            return {
              success: false,
              message: "Diagram not found: #{diagram_id}",
              available: repository.all_diagrams.map(&:name),
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
            message: "Diagram rendered successfully",
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
            error: e,
          }
        end

        # List all diagrams in repository
        #
        # @param lur_path [String] Path to LUR repository file
        # @return [Hash] Result with :success, :diagrams, :count, :message
        def list_diagrams(lur_path) # rubocop:disable Metrics/MethodLength
          repository = load_repository(lur_path)
          diagrams = repository.all_diagrams

          {
            success: true,
            count: diagrams.size,
            diagrams: diagrams.map { |d| diagram_info(d) },
          }
        rescue StandardError => e
          {
            success: false,
            message: "Failed to list diagrams: #{e.message}",
            error: e,
          }
        end

        # Extract multiple diagrams in batch
        #
        # @param lur_path [String] Path to LUR repository file
        # @param diagram_ids [Array<String>] Array of diagram IDs
        # @param opts [Hash] Additional options
        # @option opts [String] :output_dir Output directory
        # @return [Hash] Result with :success, :results, :summary
        def extract_batch(lur_path, diagram_ids, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          merged_opts = @options.merge(opts)
          output_dir = merged_opts[:output_dir] || "."

          # Create output directory if needed
          FileUtils.mkdir_p(output_dir)

          results = diagram_ids.map do |diagram_id|
            output_path = File.join(output_dir,
                                    "#{sanitize_filename(diagram_id)}.svg")
            extract_one(lur_path, diagram_id,
                        merged_opts.merge(output: output_path))
          end

          successful = results.count { |r| r[:success] }
          failed = results.count { |r| !r[:success] }

          {
            success: failed.zero?,
            results: results,
            summary: {
              total: diagram_ids.size,
              successful: successful,
              failed: failed,
            },
          }
        rescue StandardError => e
          {
            success: false,
            message: "Batch extraction failed: #{e.message}",
            error: e,
          }
        end

        private

        # Resolve options from defaults, environment, and parameters
        def resolve_options(opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          resolved = DEFAULT_OPTIONS.dup

          # Environment variables
          if ENV["LUTAML_DIAGRAM_PADDING"]
            resolved[:padding] =
              ENV["LUTAML_DIAGRAM_PADDING"].to_i
          end
          if ENV["LUTAML_DIAGRAM_BG_COLOR"]
            resolved[:background_color] =
              ENV["LUTAML_DIAGRAM_BG_COLOR"]
          end
          if ENV["LUTAML_DIAGRAM_GRID"]
            resolved[:grid_visible] =
              ENV["LUTAML_DIAGRAM_GRID"] == "true"
          end
          if ENV["LUTAML_DIAGRAM_INTERACTIVE"]
            resolved[:interactive] =
              ENV["LUTAML_DIAGRAM_INTERACTIVE"] == "true"
          end
          if ENV["LUTAML_DIAGRAM_CONFIG"]
            resolved[:config_path] =
              ENV["LUTAML_DIAGRAM_CONFIG"]
          end

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
          # Try exact match by name first
          diagram = repository.find_diagram(diagram_id)
          return diagram if diagram

          all_diagrams = repository.all_diagrams

          # Try exact match by XMI ID
          diagram = all_diagrams.find { |d| d.xmi_id == diagram_id }
          return diagram if diagram

          # Try partial name match (case-insensitive)
          all_diagrams.find do |d|
            d.name.downcase.include?(diagram_id.downcase)
          end
        end

        # Convert diagram to rendering format
        def convert_to_rendering_format(diagram, repository)
          element_map = build_element_map(repository)
          elements = build_elements(diagram, element_map)
          connectors = build_connectors(diagram, repository, element_map)

          # Normalize coordinates to EA SVG format (y-flipped, origin-based)
          normalized = normalize_coordinates(elements, connectors)

          {
            name: diagram.name,
            elements: normalized[:elements],
            connectors: normalized[:connectors],
          }
        end

        # Normalize EA coordinates to SVG coordinate system
        # EA uses y-up convention; SVG uses y-down.
        # Also shifts all coordinates so minimum x,y is at padding offset.
        def normalize_coordinates(elements, connectors) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return { elements: elements, connectors: connectors } if elements.empty?

          padding = 10

          # Find bounding box in EA coordinate space
          min_left = elements.map { |e| e[:x] }.min
          max_top = elements.map { |e| e[:y] }.max

          # In EA: y increases upward, top > bottom, height = top - bottom
          # For SVG: flip y so y increases downward
          # After negation, the element with max EA y maps to the smallest SVG y.
          # Shift so that smallest SVG y maps to padding.
          x_offset = min_left - padding
          y_offset = -max_top - padding

          normalized_elements = elements.map do |e|
            e.merge(
              x: e[:x] - x_offset,
              y: -e[:y] - y_offset,
            )
          end

          normalized_connectors = connectors.map do |c|
            c = c.dup
            if c[:source_element]
              src = c[:source_element].dup
              src[:x] = src[:x] - x_offset
              src[:y] = -src[:y] - y_offset
              c[:source_element] = src
            end
            if c[:target_element]
              tgt = c[:target_element].dup
              tgt[:x] = tgt[:x] - x_offset
              tgt[:y] = -tgt[:y] - y_offset
              c[:target_element] = tgt
            end
            c
          end

          { elements: normalized_elements, connectors: normalized_connectors }
        end

        # Build comprehensive element map keyed by XMI ID
        # Handles classes, packages, instances, and EA prefix normalization
        def build_element_map(repository) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          map = {}
          repository.classes_index.each { |c| map[c.xmi_id] = c }
          repository.packages_index.each { |p| map[p.xmi_id] = p }

          # Collect instances from packages recursively
          document = repository.document
          document.packages&.each { |pkg| collect_instances(pkg, map) }

          # Add EA prefix-normalized entries (EAID_ <-> EAPK_ etc.)
          prefix_normalized = {}
          map.each do |xmi_id, element|
            guid = ea_guid(xmi_id)
            prefix_normalized["EAID_#{guid}"] = element
            prefix_normalized["EAPK_#{guid}"] = element
          end
          map.merge!(prefix_normalized)

          map
        end

        # Extract GUID portion from EA XMI ID (strip EAID_, EAPK_ prefix)
        def ea_guid(xmi_id)
          xmi_id.sub(/\A(EAID|EAPK)_/, "")
        end

        # Recursively collect instances from packages
        def collect_instances(pkg, map)
          pkg.instances&.each { |i| map[i.xmi_id] = i }
          pkg.packages&.each { |p| collect_instances(p, map) }
        end

        # Build element data from diagram objects
        def build_elements(diagram, element_map) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          diagram.diagram_objects.filter_map do |obj|
            uml_element = element_map[obj.object_xmi_id]
            next unless uml_element

            element_data = {
              id: obj.diagram_object_id || obj.object_xmi_id,
              type: element_type(uml_element),
              name: uml_element.name,
              x: obj.left || 0,
              y: obj.top || 0,
              width: ((obj.right || 0) - (obj.left || 0)).abs.nonzero? || 120,
              height: ((obj.bottom || 0) - (obj.top || 0)).abs.nonzero? || 80,
              style: obj.style,
            }

            # Add stereotype
            if uml_element.stereotype
              element_data[:stereotype] =
                array_value(uml_element.stereotype).first
            end

            # Add class-specific data
            if element_data[:type] == "class"
              add_class_data(element_data,
                             uml_element)
            end

            element_data
          end
        end

        # Build connector data from diagram links
        def build_connectors(diagram, repository, element_map) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          diagram.diagram_links.filter_map do |link| # rubocop:disable Metrics/BlockLength
            connector = find_connector(link.connector_xmi_id, repository)
            next unless connector

            if connector.owner_end_xmi_id
              source_obj = find_diagram_object_by_element(
                connector.owner_end_xmi_id, diagram, element_map
              )
            end
            if connector.member_end_xmi_id
              target_obj = find_diagram_object_by_element(
                connector.member_end_xmi_id, diagram, element_map
              )
            end

            connector_data = {
              id: link.connector_id || link.connector_xmi_id,
              type: connector_type(connector),
              element: connector,
              diagram_link: link,
              style: link.style,
              geometry: link.geometry,
              path: link.path,
            }

            # Add source/target positions
            if source_obj
              connector_data[:source_element] = diagram_object_bounds(source_obj)
            end

            if target_obj
              connector_data[:target_element] = diagram_object_bounds(target_obj)
            end

            # Add role and multiplicity
            add_connector_metadata(connector_data, connector)

            connector_data
          end
        end

        # Add class attributes and operations
        def add_class_data(element_data, uml_element) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          if uml_element.attributes
            element_data[:attributes] = uml_element.attributes.map do |attr|
              {
                name: attr.name,
                type: attr.type,
                visibility: attr.visibility || "public",
              }
            end
          end

          if uml_element.operations
            element_data[:operations] = uml_element.operations.map do |op|
              {
                name: op.name,
                return_type: op.return_type,
                visibility: op.visibility || "public",
                parameters: op.parameters&.map do |p|
                  { name: p.name, type: p.type }
                end || [],
              }
            end
          end
        end

        # Add connector role and multiplicity information
        def add_connector_metadata(connector_data, connector) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          if connector.owner_end_attribute_name
            connector_data[:source_role] =
              connector.owner_end_attribute_name
          end
          if connector.member_end_attribute_name
            connector_data[:target_role] =
              connector.member_end_attribute_name
          end

          if connector.owner_end_cardinality
            connector_data[:source_multiplicity] =
              format_cardinality(connector.owner_end_cardinality)
          end

          if connector.member_end_cardinality
            connector_data[:target_multiplicity] =
              format_cardinality(connector.member_end_cardinality)
          end
        end

        # Find UML element by XMI ID
        def find_element(xmi_id, repository)
          repository.classes_index.find { |c| c.xmi_id == xmi_id } ||
            repository.packages_index.find { |p| p.xmi_id == xmi_id }
        end

        # Find connector by XMI ID
        def find_connector(xmi_id, repository)
          repository.associations_index.find { |a| a.xmi_id == xmi_id }
        end

        # Find diagram object for element, with EA prefix normalization
        def find_diagram_object_by_element(element_xmi_id, diagram, element_map)
          # The element_map has normalized keys, find the original XMI ID
          element = element_map[element_xmi_id]
          return nil unless element

          # Find the diagram object that references this element
          diagram.diagram_objects.find do |obj|
            obj.object_xmi_id == element_xmi_id ||
              element_map[obj.object_xmi_id] == element
          end
        end

        # Convert diagram object bounds to x/y/width/height format
        def diagram_object_bounds(obj)
          left = obj.left || 0
          top = obj.top || 0
          right = obj.right || (left + 120)
          bottom = obj.bottom || (top + 80)
          {
            x: left,
            y: top,
            width: (right - left).abs,
            height: (bottom - top).abs,
          }
        end

        # Find diagram object for element
        def find_diagram_object(element_xmi_id, diagram)
          diagram.diagram_objects.find do |obj|
            obj.object_xmi_id == element_xmi_id
          end
        end

        # Determine element type from UML element
        def element_type(uml_element)
          case uml_element
          when Lutaml::Uml::Class then "class"
          when Lutaml::Uml::Package then "package"
          when Lutaml::Uml::DataType then "datatype"
          when Lutaml::Uml::Enum then "enumeration"
          when Lutaml::Uml::Instance then "instance"
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
            links: diagram.diagram_links&.size || 0,
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
          cardinality.to_s
        end

        # Convert value to array
        def array_value(value)
          value.is_a?(Array) ? value : [value]
        end
      end
    end
  end
end
