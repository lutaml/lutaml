# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class DiagramSerializer < Base
          def build_map
            diagrams = {}
            @repository.diagrams_index.each do |diagram|
              id = @id_generator.diagram_id(diagram)
              diagrams[id] = serialize(diagram, id)
            end
            diagrams
          rescue StandardError
            {}
          end

          private

          def serialize(diagram, id)
            Models::SpaDiagram.new(
              id: id,
              xmi_id: diagram.xmi_id,
              name: diagram.name,
              type: diagram.diagram_type,
              package: find_diagram_package(diagram),
              object_count: (diagram.diagram_objects || []).size,
              link_count: (diagram.diagram_links || []).size,
              svg: render_svg(diagram),
            )
          end

          def render_svg(diagram)
            return nil unless @options[:render_diagrams]
            return nil unless diagram.diagram_objects&.any?

            presenter = Presenters::DiagramPresenter.new(diagram, @repository)
            presenter.svg_output
          rescue StandardError
            nil
          end

          def find_diagram_package(diagram)
            @repository.packages_index.each do |pkg|
              diagrams = package_diagrams(pkg)
              if diagrams.any? { |d| d.xmi_id == diagram.xmi_id }
                return @id_generator.package_id(pkg)
              end
            end
            nil
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
