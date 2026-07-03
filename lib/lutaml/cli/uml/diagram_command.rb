# frozen_string_literal: true

module Lutaml
  module Cli
    module Uml
      # CLI command for diagram rendering
      class DiagramCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name) # rubocop:disable Metrics/MethodLength
          thor_class.long_desc <<-DESC
          Render EA diagrams to SVG format.

          This command converts Enterprise Architect diagram data into clean,
          interactive SVG files suitable for web display. The diagrams can be
          rendered from LUR packages or directly from diagram data.

          The output SVG files include proper styling, interactive elements,
          and can be embedded in web applications or documentation.

          Examples:
            lutaml uml diagram render diagram001 -o diagram001.svg
            lutaml uml diagram render diagram001 -o diagram001.svg --interactive
            lutaml uml diagram list mymodel.lur
          DESC

          thor_class.option :output, aliases: "-o", type: :string,
                                     desc: "Output SVG file path"
          thor_class.option :format, type: :string, default: "svg",
                                     desc: "Output format (svg|png)"
          thor_class.option :interactive, type: :boolean, default: true,
                                          desc: "Include interactive elements"
          thor_class.option :width, type: :numeric, desc: "Diagram width"
          thor_class.option :height, type: :numeric, desc: "Diagram height"
          thor_class.option :padding, type: :numeric, default: 20,
                                      desc: "Padding around diagram"
          thor_class.option :background, type: :string, default: "#ffffff",
                                         desc: "Background color"
          thor_class.option :grid, type: :boolean, default: false,
                                   desc: "Show grid lines"
        end

        def run(action, *args)
          case action
          when "render"
            render_diagram(args.first)
          when "list"
            list_diagrams(args.first)
          else
            puts "Unknown action: #{action}"
            puts "Available actions: render, list"
            raise Thor::Error, "Invalid action"
          end
        end

        def convert_diagram_to_rendering_format(diagram, repository)
          elements = extract_diagram_elements(diagram, repository)
          connectors = extract_diagram_connectors(diagram, repository)

          { elements: elements, connectors: connectors }
        end

        def find_uml_element_by_xmi_id(xmi_id, repository) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          # Search through all element types
          repository.classes_index.find { |c| c.xmi_id == xmi_id } ||
            repository.packages_index.find { |p| p.xmi_id == xmi_id } ||
            repository.data_types_index.find { |d| d.xmi_id == xmi_id } ||
            repository.enums_index.find { |e| e.xmi_id == xmi_id }
        end

        def find_connector_by_xmi_id(xmi_id, repository)
          # Search through associations and other connectors
          repository.associations_index.find { |a| a.xmi_id == xmi_id }
        end

        def find_diagram_object_for_element(element_xmi_id, diagram)
          diagram.diagram_objects.find do |obj|
            obj.object_xmi_id == element_xmi_id
          end
        end

        def determine_element_type(uml_element) # rubocop:disable Metrics/MethodLength
          case uml_element
          when Lutaml::Uml::Class
            "class"
          when Lutaml::Uml::Package
            "package"
          when Lutaml::Uml::DataType
            "datatype"
          when Lutaml::Uml::Enumeration
            "enumeration"
          else
            "unknown"
          end
        end

        def determine_connector_type(connector)
          case connector
          when Lutaml::Uml::Association
            "association"
          when Lutaml::Uml::Generalization
            "generalization"
          when Lutaml::Uml::Dependency
            "dependency"
          else
            "connector"
          end
        end

        def extract_diagram_elements(diagram, repository)
          diagram.diagram_objects.filter_map do |obj|
            uml_element = find_uml_element_by_xmi_id(obj.object_xmi_id,
                                                     repository)
            next unless uml_element

            build_element_data(obj, uml_element)
          end
        end

        def build_element_data(obj, uml_element)
          data = base_element_data(obj, uml_element)
          add_element_stereotype(data, uml_element)
          add_classifier_members(data, uml_element)
          data
        end

        def base_element_data(obj, uml_element)
          {
            id: obj.diagram_object_id || obj.object_xmi_id,
            type: determine_element_type(uml_element),
            name: uml_element.name,
            x: obj.left || 0,
            y: obj.top || 0,
            width: (obj.right - obj.left) || 120,
            height: (obj.bottom - obj.top) || 80,
            style: obj.style,
          }
        end

        def add_element_stereotype(data, uml_element)
          return unless uml_element.is_a?(Lutaml::Uml::TopElement)
          return unless uml_element.stereotype && !uml_element.stereotype.empty?

          data[:stereotype] = uml_element.stereotype.first
        end

        def add_classifier_members(data, uml_element)
          return unless uml_element.is_a?(Lutaml::Uml::Classifier)

          if uml_element.attributes
            data[:attributes] =
              serialize_element_attributes(uml_element.attributes)
          end
          if uml_element.operations
            data[:operations] =
              serialize_element_operations(uml_element.operations)
          end
        end

        def serialize_element_attributes(attributes)
          attributes.map do |attr|
            { name: attr.name, type: attr.type,
              visibility: attr.visibility || "public" }
          end
        end

        def serialize_element_operations(operations)
          operations.map do |op|
            { name: op.name, return_type: op.return_type,
              visibility: op.visibility || "public",
              parameters: op.parameters&.map do |p|
                { name: p.name, type: p.type }
              end || [] }
          end
        end

        def extract_diagram_connectors(diagram, repository)
          diagram.diagram_links.filter_map do |link|
            connector = find_connector_by_xmi_id(link.connector_xmi_id,
                                                 repository)
            next unless connector

            build_connector_data(link, connector, diagram)
          end
        end

        def build_connector_data(link, connector, diagram)
          data = {
            id: link.connector_id || link.connector_xmi_id,
            type: determine_connector_type(connector),
            style: link.style,
            geometry: link.geometry,
            path: link.path,
          }

          add_association_metadata(data, connector)
          add_connector_coordinates(data, connector, diagram)

          data
        end

        def add_association_metadata(data, connector)
          return unless connector.is_a?(Lutaml::Uml::Association)

          if connector.owner_end_attribute_name
            data[:source_role] =
              connector.owner_end_attribute_name
          end
          if connector.member_end_attribute_name
            data[:target_role] =
              connector.member_end_attribute_name
          end
          if connector.owner_end_cardinality
            data[:source_multiplicity] =
              format_cardinality(connector.owner_end_cardinality)
          end
          if connector.member_end_cardinality
            data[:target_multiplicity] =
              format_cardinality(connector.member_end_cardinality)
          end
        end

        def add_connector_coordinates(data, connector, diagram)
          return unless connector.is_a?(Lutaml::Uml::Association)

          if connector.owner_end && connector.source
            add_endpoint_coords(data, connector.source.xmi_id, diagram,
                                :source_x, :source_y)
          end

          return unless connector.member_end && connector.target

          add_endpoint_coords(data, connector.target.xmi_id, diagram,
                              :target_x, :target_y)
        end

        def add_endpoint_coords(data, xmi_id, diagram, x_key, y_key)
          obj = find_diagram_object_for_element(xmi_id, diagram)
          return unless obj

          data[x_key] = obj.left + ((obj.right - obj.left) / 2)
          data[y_key] = obj.top + ((obj.bottom - obj.top) / 2)
        end

        private

        def render_diagram(diagram_id)
          puts "Loading repository to render diagram: #{diagram_id}"

          begin
            repository = Lutaml::UmlRepository::Repository
              .from_package(options[:lur_path] || "examples/lur/basic.lur")

            diagram = resolve_diagram(repository, diagram_id)
            print_diagram_info(diagram)

            diagram_data = convert_diagram_to_rendering_format(diagram,
                                                               repository)
            svg_content = Lutaml::Ea::Diagram.render(diagram_data, options)
            write_diagram_output(diagram, svg_content)
          rescue StandardError => e
            puts "Error rendering diagram: #{e.message}"
            raise Thor::Error, "Failed to render diagram: #{e.message}"
          end
        end

        def resolve_diagram(repository, diagram_id)
          diagram = repository.find_diagram(diagram_id)
          return diagram if diagram

          repository.all_diagrams.find do |d|
            d.name.downcase.include?(diagram_id.downcase)
          end || raise_diagram_not_found(repository, diagram_id)
        end

        def raise_diagram_not_found(repository, diagram_id)
          puts "Diagram not found: #{diagram_id}"
          puts "Available diagrams:"
          repository.all_diagrams.each { |d| puts "  - #{d.name}" }
          raise Thor::Error, "Diagram not found: #{diagram_id}"
        end

        def print_diagram_info(diagram)
          puts "Found diagram: #{diagram.name}"
          puts "  Type: #{diagram.diagram_type}"
          puts "  Objects: #{diagram.diagram_objects.size}"
          puts "  Links: #{diagram.diagram_links.size}"
        end

        def write_diagram_output(diagram, svg_content)
          output_path = options[:output] ||
            "#{diagram.name.gsub(/[^a-zA-Z0-9]/, '_')}.svg"
          File.write(output_path, svg_content)
          puts "Diagram rendered to: #{output_path}"
        end

        def list_diagrams(lur_path)
          raise "LUR file not found: #{lur_path}" unless File.exist?(lur_path)

          puts "Loading repository from: #{lur_path}"

          begin
            repository = Lutaml::UmlRepository::Repository.from_package(lur_path)
            diagrams = repository.all_diagrams

            return puts("No diagrams found in the repository.") if diagrams.empty?

            print_diagram_list(diagrams)
          rescue StandardError => e
            puts "Error loading repository: #{e.message}"
            raise Thor::Error, "Failed to load repository: #{e.message}"
          end
        end

        def print_diagram_list(diagrams)
          puts "\nDiagrams found: #{diagrams.size}"
          puts "=" * 50
          diagrams.each_with_index { |d, i| print_diagram_entry(d, i) }
          puts "\n#{'=' * 50}"
          puts "Total: #{diagrams.size} diagrams"
        end

        def print_diagram_entry(diagram, index)
          puts "\n[#{index + 1}] #{diagram.name}"
          puts "  Type: #{diagram.diagram_type}"
          puts "  XMI ID: #{diagram.xmi_id}"
          puts "  Package: #{diagram.package_name || 'Unknown'}"
          puts "  Objects: #{diagram.diagram_objects.size}" if diagram.diagram_objects&.any?
          puts "  Links: #{diagram.diagram_links.size}" if diagram.diagram_links&.any?
        end

        SAMPLE_DIAGRAM_DATA = {
          elements: [
            {
              id: "class1",
              type: "class",
              name: "SampleClass",
              stereotype: "entity",
              x: 50,
              y: 50,
              width: 120,
              height: 80,
              attributes: [
                { name: "id", type: "Integer", visibility: "private" },
                { name: "name", type: "String", visibility: "private" },
              ],
              operations: [
                { name: "getName", return_type: "String",
                  visibility: "public" },
                { name: "setName",
                  parameters: [{ name: "name", type: "String" }],
                  visibility: "public" },
              ],
            },
            {
              id: "class2",
              type: "class",
              name: "AnotherClass",
              x: 250,
              y: 50,
              width: 120,
              height: 80,
            },
            {
              id: "package1",
              type: "package",
              name: "SamplePackage",
              x: 50,
              y: 200,
              width: 120,
              height: 80,
            },
          ],
          connectors: [
            {
              id: "conn1",
              type: "association",
              source_x: 170,
              source_y: 90,
              target_x: 250,
              target_y: 90,
              source_role: "parent",
              target_role: "child",
              source_multiplicity: "1",
              target_multiplicity: "0..*",
            },
            {
              id: "conn2",
              type: "generalization",
              source_x: 110,
              source_y: 130,
              target_x: 110,
              target_y: 200,
            },
          ],
        }.freeze

        def create_sample_diagram_data
          SAMPLE_DIAGRAM_DATA
        end

        # Format cardinality for display
        def format_cardinality(cardinality)
          return "" unless cardinality

          cardinality.to_s
        end
      end
    end
  end
end
