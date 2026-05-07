# frozen_string_literal: true

require_relative "../../presenters/diagram_presenter"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class DiagramSerializer
          def initialize(repository, id_generator, options)
            @repository = repository
            @id_generator = id_generator
            @options = options
          end

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
            data = {
              id: id,
              xmiId: diagram.xmi_id,
              name: diagram.name,
              type: diagram.diagram_type,
              package: find_diagram_package(diagram),
              objectCount: (diagram.diagram_objects || []).size,
              linkCount: (diagram.diagram_links || []).size,
            }

            if @options[:render_diagrams]
              svg = render_svg(diagram)
              data[:svg] = svg if svg
            end

            data
          end

          def render_svg(diagram)
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

          def package_diagrams(package)
            return [] unless @options[:include_diagrams]

            package.diagrams || []
          rescue StandardError
            []
          end
        end
      end
    end
  end
end
