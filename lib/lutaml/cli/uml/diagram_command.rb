# frozen_string_literal: true

require_relative "../../ea/diagram"

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

        def convert_diagram_to_rendering_format(diagram, repository) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          elements = []
          connectors = []

          # Process diagram objects (visual elements)
          diagram.diagram_objects.each do |obj| # rubocop:disable Metrics/BlockLength
            # Find the actual UML element that this diagram object represents
            uml_element = find_uml_element_by_xmi_id(obj.object_xmi_id,
                                                     repository)
            next unless uml_element

            # Convert to rendering format
            element_data = {
              id: obj.diagram_object_id || obj.object_xmi_id,
              type: determine_element_type(uml_element),
              name: uml_element.name,
              x: obj.left || 0,
              y: obj.top || 0,
              width: (obj.right - obj.left) || 120,
              height: (obj.bottom - obj.top) || 80,
              style: obj.style,
            }

            # Add stereotype if available
            if uml_element.respond_to?(:stereotype) && uml_element.stereotype
              element_data[:stereotype] = if uml_element.stereotype.is_a?(Array)
                                            uml_element.stereotype.first
                                          else
                                            uml_element.stereotype
                                          end
            end

            # Add attributes and operations for classes
            if uml_element.respond_to?(:attributes) && uml_element.attributes
              element_data[:attributes] = uml_element.attributes.map do |attr|
                {
                  name: attr.name,
                  type: attr.type,
                  visibility: attr.visibility || "public",
                }
              end
            end

            if uml_element.respond_to?(:operations) && uml_element.operations
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

            elements << element_data
          end

          # Process diagram links (connectors/relationships)
          diagram.diagram_links.each do |link| # rubocop:disable Metrics/BlockLength
            # Find the actual connector that this diagram link represents
            connector = find_connector_by_xmi_id(link.connector_xmi_id,
                                                 repository)
            next unless connector

            # Convert to rendering format
            connector_data = {
              id: link.connector_id || link.connector_xmi_id,
              type: determine_connector_type(connector),
              style: link.style,
              geometry: link.geometry,
              path: link.path,
            }

            # Add role and multiplicity information if available
            if connector.respond_to?(:owner_end_attribute_name) &&
                connector.owner_end_attribute_name
              connector_data[:source_role] = connector.owner_end_attribute_name
            end

            if connector.respond_to?(:member_end_attribute_name) &&
                connector.member_end_attribute_name
              connector_data[:target_role] = connector.member_end_attribute_name
            end

            if connector.respond_to?(:owner_end_cardinality) &&
                connector.owner_end_cardinality
              connector_data[:source_multiplicity] =
                format_cardinality(connector.owner_end_cardinality)
            end

            if connector.respond_to?(:member_end_cardinality) &&
                connector.member_end_cardinality
              connector_data[:target_multiplicity] =
                format_cardinality(connector.member_end_cardinality)
            end

            # Add source and target information if available
            if connector.respond_to?(:source) && connector.source
              source_obj = find_diagram_object_for_element(
                connector.source.xmi_id, diagram
              )
              if source_obj
                connector_data[:source_x] =
                  source_obj.left + ((source_obj.right - source_obj.left) / 2)
                connector_data[:source_y] =
                  source_obj.top + ((source_obj.bottom - source_obj.top) / 2)
              end
            end

            if connector.respond_to?(:target) && connector.target
              target_obj = find_diagram_object_for_element(
                connector.target.xmi_id, diagram
              )
              if target_obj
                connector_data[:target_x] =
                  target_obj.left + ((target_obj.right - target_obj.left) / 2)
                connector_data[:target_y] =
                  target_obj.top + ((target_obj.bottom - target_obj.top) / 2)
              end
            end

            connectors << connector_data
          end

          {
            elements: elements,
            connectors: connectors,
          }
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

        private

        def render_diagram(diagram_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          # For now, this extracts real diagram data from repository
          # In a full implementation, this would render the actual diagram

          puts "Loading repository to render diagram: #{diagram_id}"

          begin
            repository = Lutaml::UmlRepository::Repository
              .from_package(options[:lur_path] || "examples/lur/basic.lur")

            # Find the diagram by name or ID
            diagram = repository.find_diagram(diagram_id)

            unless diagram
              # Try to find by partial name match
              all_diagrams = repository.all_diagrams
              diagram = all_diagrams.find do |d|
                d.name.downcase.include?(diagram_id.downcase)
              end
            end

            unless diagram
              puts "Diagram not found: #{diagram_id}"
              puts "Available diagrams:"
              repository.all_diagrams.each { |d| puts "  - #{d.name}" }
              raise Thor::Error, "Diagram not found: #{diagram_id}"
            end

            puts "Found diagram: #{diagram.name}"
            puts "  Type: #{diagram.diagram_type}"
            puts "  Objects: #{diagram.diagram_objects.size}"
            puts "  Links: #{diagram.diagram_links.size}"

            # Convert diagram data to rendering format
            diagram_data = convert_diagram_to_rendering_format(diagram,
                                                               repository)

            # Render using the diagram module
            svg_content = Lutaml::Ea::Diagram.render(diagram_data, options)

            # Write to output file
            output_path = options[:output] || "#{diagram.name.gsub(
              /[^a-zA-Z0-9]/, '_'
            )}.svg"
            File.write(output_path, svg_content)

            puts "Diagram rendered to: #{output_path}"
          rescue StandardError => e
            puts "Error rendering diagram: #{e.message}"
            raise Thor::Error, "Failed to render diagram: #{e.message}"
          end
        end

        def list_diagrams(lur_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          unless File.exist?(lur_path)
            puts "LUR file not found: #{lur_path}"
            raise Thor::Error, "LUR file not found"
          end

          puts "Loading repository from: #{lur_path}"

          begin
            repository = Lutaml::UmlRepository::Repository.from_package(lur_path)
            diagrams = repository.all_diagrams

            if diagrams.empty?
              puts "No diagrams found in the repository."
              return
            end

            puts "\nDiagrams found: #{diagrams.size}"
            puts "=" * 50

            diagrams.each_with_index do |diagram, index|
              puts "\n[#{index + 1}] #{diagram.name}"
              puts "  Type: #{diagram.diagram_type}"
              puts "  XMI ID: #{diagram.xmi_id}"
              puts "  Package: #{diagram.package_name || 'Unknown'}"

              if diagram.diagram_objects && !diagram.diagram_objects.empty?
                puts "  Objects: #{diagram.diagram_objects.size}"
              end

              if diagram.diagram_links && !diagram.diagram_links.empty?
                puts "  Links: #{diagram.diagram_links.size}"
              end
            end

            puts "\n#{'=' * 50}"
            puts "Total: #{diagrams.size} diagrams"
          rescue StandardError => e
            puts "Error loading repository: #{e.message}"
            raise Thor::Error, "Failed to load repository: #{e.message}"
          end
        end

        def create_sample_diagram_data
          # Sample diagram data for testing the rendering pipeline
          {
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
          }
        end

        # Format cardinality for display
        def format_cardinality(cardinality)
          return "" unless cardinality

          if cardinality.respond_to?(:to_s)
            cardinality.to_s
          else
            ""
          end
        end
      end
    end
  end
end