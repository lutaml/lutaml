# frozen_string_literal: true

require_relative "element_presenter"
require_relative "../../ea/diagram/svg_renderer"
require_relative "../../ea/diagram/layout_engine"
require_relative "../../ea/diagram/style_resolver"

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML Diagram elements
      #
      # Coordinates the entire diagram rendering pipeline by:
      # 1. Loading elements and connectors from the repository
      # 2. Converting EA coordinates to SVG format
      # 3. Using StyleResolver to merge EA data + config + defaults
      # 4. Creating a DiagramRenderer wrapper
      # 5. Generating SVG output via SvgRenderer
      class DiagramPresenter < ElementPresenter
        attr_reader :config_path

        # @param diagram [Lutaml::Uml::Diagram] The diagram to present
        # @param repository [Repository] Repository for looking up elements
        # @param options [Hash] Rendering options
        # @option options [String] :config_path Path to diagram configuration
        def initialize(diagram, repository, options = {})
          super(diagram, repository)
          @config_path = options[:config_path]
          @layout_engine = Ea::Diagram::LayoutEngine.new
        end

        # Generate SVG output for the diagram
        #
        # @param options [Hash] Rendering options
        # @option options [Integer] :padding (20) Padding around diagram
        # @option options [String] :background_color ("#ffffff") Background color
        # @option options [Boolean] :grid_visible (false) Show grid
        # @option options [Boolean] :interactive (false) Enable interactive features
        # @return [String] Complete SVG content
        def svg_output(options = {})
          # Build diagram data structure
          diagram_data = {
            name: element.name,
            elements: build_elements_data,
            connectors: build_connectors_data
          }

          # Create diagram renderer wrapper
          diagram_renderer = DiagramRendererWrapper.new(diagram_data, @layout_engine)

          # Create SVG renderer with configuration
          renderer_options = options.merge(config_path: config_path)
          svg_renderer = Ea::Diagram::SvgRenderer.new(diagram_renderer, renderer_options)

          # Generate and return SVG
          svg_renderer.render
        end

        # Get elements in the diagram
        #
        # @return [Array<Hash>] Array of element data hashes
        def elements
          build_elements_data
        end

        # Get connectors in the diagram
        #
        # @return [Array<Hash>] Array of connector data hashes
        def connectors
          build_connectors_data
        end

        # Text output for diagram
        def to_text
          lines = []
          lines << "Diagram: #{element.name}"
          lines << ("=" * 50)
          lines << ""
          lines << "Type:          #{element.diagram_type}"
          lines << "Package:       #{element.package_name || 'Unknown'}"
          lines << "Elements:      #{(element.diagram_objects || []).count}"
          lines << "Connectors:    #{(element.diagram_links || []).count}"
          lines.join("\n")
        end

        # Table row for diagram
        def to_table_row
          {
            type: "Diagram",
            name: element.name || "(unnamed)",
            details: "#{element.diagram_type} - #{(element.diagram_objects || []).count} elements"
          }
        end

        # Hash representation
        def to_hash
          {
            type: "Diagram",
            name: element.name,
            diagram_type: element.diagram_type,
            package_name: element.package_name,
            elements_count: (element.diagram_objects || []).count,
            connectors_count: (element.diagram_links || []).count
          }
        end

        private

        # Build element data from diagram_objects
        #
        # @return [Array<Hash>] Array of element data for rendering
        def build_elements_data
          return [] unless element.diagram_objects

          element.diagram_objects.map do |diagram_object|
            # Look up the actual element in the repository
            uml_element = find_element_by_xmi_id(diagram_object.object_xmi_id)
            next nil unless uml_element

            # Convert EA coordinates to SVG format
            coords = @layout_engine.convert_ea_coordinates(diagram_object)

            # Build element data hash
            {
              id: diagram_object.object_xmi_id,
              name: uml_element.name,
              type: determine_element_type(uml_element),
              x: coords[:x],
              y: coords[:y],
              width: coords[:width],
              height: coords[:height],
              stereotype: extract_stereotype(uml_element),
              attributes: extract_attributes(uml_element),
              operations: extract_operations(uml_element),
              element: uml_element,           # Original UML element
              diagram_object: diagram_object  # Original diagram placement data
            }
          end.compact
        end

        # Build connector data from diagram_links
        #
        # @return [Array<Hash>] Array of connector data for rendering
        def build_connectors_data
          return [] unless element.diagram_links

          # Build elements index for quick lookup by XMI ID
          elements_map = build_elements_data.each_with_object({}) do |elem, hash|
            hash[elem[:id]] = elem
          end

          # Build diagram objects map for EA internal ID lookup
          diagram_objects_map = {}
          if element.diagram_objects
            element.diagram_objects.each do |dobj|
              diagram_objects_map[extract_ea_id(dobj)] = dobj.object_xmi_id
            end
          end

          element.diagram_links.map do |diagram_link|
            # Skip hidden connectors
            next nil if diagram_link.hidden

            # Look up the actual connector in the repository
            connector = find_connector_by_xmi_id(diagram_link.connector_xmi_id)

            # Even if connector object not found, we can still render using geometry
            # The diagram_link contains all visual information needed
            connector_type = if connector
              determine_connector_type(connector)
            else
              # Default to association if connector object not found
              "association"
            end

            # Parse source and target from diagram_link style (contains SOID/EOID)
            style_data = parse_diagram_link_style(diagram_link.style)

            source_elem = nil
            target_elem = nil

            # Try to find elements using EA internal IDs from style
            if style_data[:soid]
              source_xmi_id = diagram_objects_map[style_data[:soid]]
              source_elem = elements_map[source_xmi_id] if source_xmi_id
            end

            if style_data[:eoid]
              target_xmi_id = diagram_objects_map[style_data[:eoid]]
              target_elem = elements_map[target_xmi_id] if target_xmi_id
            end

            # Fallback: try to find from connector object if style parsing failed
            if !source_elem || !target_elem
              if connector
                source_elem ||= find_connector_source(connector, elements_map)
                target_elem ||= find_connector_target(connector, elements_map)
              end
            end

            # Build connector data hash
            {
              id: diagram_link.connector_xmi_id,
              type: connector_type,
              geometry: diagram_link.geometry,
              style: diagram_link.style,
              source_element: source_elem,    # Source element for geometry calculation
              target_element: target_elem,    # Target element for geometry calculation
              element: connector,             # May be nil if not found
              diagram_link: diagram_link      # Original diagram routing data
            }
          end.compact
        end

        # Parse EA diagram link style string
        #
        # Style format: "Mode=3;EOID=82C649C4;SOID=21096985;Color=-1;LWidth=2;TREE=V;"
        # SOID = Source Object ID (EA internal ID)
        # EOID = End Object ID (EA internal ID)
        #
        # @param style_string [String] EA style string
        # @return [Hash] Parsed style data
        def parse_diagram_link_style(style_string)
          return {} unless style_string

          data = {}
          style_string.split(";").each do |pair|
            next if pair.empty?
            key, value = pair.split("=", 2)
            next unless key && value

            case key.strip
            when "SOID"
              data[:soid] = value.strip
            when "EOID"
              data[:eoid] = value.strip
            end
          end
          data
        end

        # Extract EA internal ID from diagram object
        #
        # @param diagram_object [Object] Diagram object
        # @return [String, nil] EA internal ID (DUID from style)
        def extract_ea_id(diagram_object)
          # EA stores the internal ID as DUID in the style string
          return nil unless diagram_object.respond_to?(:style) && diagram_object.style

          # Parse DUID from style string
          # Style format: "NSL=0;LCol=-1;...;DUID=82C649C4;BCol=16764159;..."
          style = diagram_object.style
          match = style.match(/DUID=([^;]+)/)
          return match[1] if match

          nil
        end

        # Find element in repository by XMI ID
        #
        # @param xmi_id [String] XMI identifier
        # @return [Object, nil] UML element or nil if not found
        def find_element_by_xmi_id(xmi_id)
          return nil unless xmi_id && repository

          # Try to find in classes index (includes classes, datatypes, enums)
          element = repository.classes_index.find { |cls| cls.xmi_id == xmi_id }
          return element if element

          # Try to find in packages index
          repository.packages_index.find { |pkg| pkg.xmi_id == xmi_id }
        end

        # Find connector in repository by XMI ID
        #
        # @param xmi_id [String] XMI identifier
        # @return [Object, nil] UML connector or nil if not found
        def find_connector_by_xmi_id(xmi_id)
          return nil unless xmi_id && repository

          # Look in document-level associations index
          connector = repository.associations_index.find { |assoc| assoc.xmi_id == xmi_id }
          return connector if connector

          # Look in class-level generalizations
          repository.classes_index.each do |klass|
            next unless klass.respond_to?(:generalization) && klass.generalization

            gen = klass.generalization
            # Handle both single generalization and array of generalizations
            generalizations = gen.is_a?(Array) ? gen : [gen]

            generalizations.each do |g|
              return g if g.respond_to?(:xmi_id) && g.xmi_id == xmi_id
            end
          end

          # Look in class-level associations
          repository.classes_index.each do |klass|
            next unless klass.respond_to?(:associations) && klass.associations

            assoc = klass.associations.find { |a| a.respond_to?(:xmi_id) && a.xmi_id == xmi_id }
            return assoc if assoc
          end

          nil
        end

        # Find connector target element
        #
        # @param connector [Object] UML connector
        # @param elements_map [Hash] Map of element ID to element data
        # @return [Hash, nil] Target element data
        def find_connector_target(connector, elements_map)
          target_id = nil

          if connector.respond_to?(:target) && connector.target
            target_id = connector.target
          elsif connector.respond_to?(:supplier) && connector.supplier
            target_id = connector.supplier
          elsif connector.respond_to?(:general) && connector.general
            target_id = connector.general
          elsif connector.respond_to?(:member_end) && connector.member_end
            # For associations, use the second member_end
            ends = connector.member_end.is_a?(Array) ? connector.member_end : [connector.member_end]
            if ends.size > 1
              target_id = ends[1]
            end
          end

          elements_map[target_id]
        end

        # Find connector source element
        #
        # @param connector [Object] UML connector
        # @param elements_map [Hash] Map of element ID to element data
        # @return [Hash, nil] Source element data
        def find_connector_source(connector, elements_map)
          source_id = nil

          if connector.respond_to?(:source) && connector.source
            source_id = connector.source
          elsif connector.respond_to?(:client) && connector.client
            source_id = connector.client
          elsif connector.respond_to?(:specific) && connector.specific
            source_id = connector.specific
          elsif connector.respond_to?(:owner_end) && connector.owner_end
            source_id = connector.owner_end
          elsif connector.respond_to?(:member_end) && connector.member_end
            # For associations, use the first member_end
            ends = connector.member_end.is_a?(Array) ? connector.member_end : [connector.member_end]
            if ends.any?
              source_id = ends[0]
            end
          end

          elements_map[source_id]
        end

        # Determine element type for rendering
        #
        # @param uml_element [Object] UML element
        # @return [String] Element type
        def determine_element_type(uml_element)
          case uml_element.class.name
          when /DataType/
            "datatype"
          when /Enum/
            "enum"
          when /Class/
            "class"
          when /Package/
            "package"
          else
            "class"
          end
        end

        # Determine connector type for rendering
        #
        # @param connector [Object] UML connector
        # @return [String] Connector type
        def determine_connector_type(connector)
          case connector.class.name
          when /Generalization/
            "generalization"
          when /Association/
            "association"
          when /Dependency/
            "dependency"
          when /Realization/
            "realization"
          else
            "association"
          end
        end

        # Extract stereotype from element
        #
        # @param uml_element [Object] UML element
        # @return [String, nil] Stereotype name
        def extract_stereotype(uml_element)
          return nil unless uml_element.respond_to?(:stereotype)

          stereotype = uml_element.stereotype
          return nil unless stereotype

          # Handle array of stereotypes
          if stereotype.is_a?(Array)
            stereotype.first
          else
            stereotype
          end
        end

        # Extract attributes from element
        #
        # @param uml_element [Object] UML element
        # @return [Array<Hash>] Array of attribute data
        def extract_attributes(uml_element)
          return [] unless uml_element.respond_to?(:attributes)
          return [] unless uml_element.attributes

          uml_element.attributes.map do |attr|
            {
              name: attr.name,
              type: attr.type,
              visibility: attr.respond_to?(:visibility) ? attr.visibility : nil
            }
          end
        end

        # Extract operations from element
        #
        # @param uml_element [Object] UML element
        # @return [Array<Hash>] Array of operation data
        def extract_operations(uml_element)
          return [] unless uml_element.respond_to?(:operations)
          return [] unless uml_element.operations

          uml_element.operations.map do |op|
            {
              name: op.name,
              visibility: op.respond_to?(:visibility) ? op.visibility : nil,
              return_type: op.respond_to?(:return_type) ? op.return_type : nil,
              parameters: extract_parameters(op)
            }
          end
        end

        # Extract parameters from operation
        #
        # @param operation [Object] UML operation
        # @return [Array<Hash>] Array of parameter data
        def extract_parameters(operation)
          return [] unless operation.respond_to?(:owned_parameter)
          return [] unless operation.owned_parameter

          operation.owned_parameter.map do |param|
            {
              name: param.name,
              type: param.type
            }
          end
        end

        # Wrapper class to adapt diagram data to SvgRenderer expectations
        class DiagramRendererWrapper
          attr_reader :diagram_data, :bounds, :elements, :connectors

          def initialize(diagram_data, layout_engine)
            @diagram_data = diagram_data
            @elements = diagram_data[:elements] || []
            @connectors = diagram_data[:connectors] || []
            @bounds = layout_engine.calculate_bounds(diagram_data)
          end
        end
      end

      # Register with factory
      PresenterFactory.register(
        Lutaml::Uml::Diagram,
        DiagramPresenter,
      )
    end
  end
end
