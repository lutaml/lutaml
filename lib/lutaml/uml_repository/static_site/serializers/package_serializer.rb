# frozen_string_literal: true

require_relative "../../../uml/model_helpers"
require_relative "../models/spa_package"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class PackageSerializer
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator, options)
            @repository = repository
            @id_generator = id_generator
            @options = options
          end

          def build_map
            packages = {}
            @repository.packages_index.each do |package|
              id = @id_generator.package_id(package)
              packages[id] = serialize(package, id)
            end
            packages
          end

          private

          def serialize(package, id)
            Models::SpaPackage.new(
              id: id,
              xmi_id: package.xmi_id,
              name: package.name,
              path: package_path(package),
              definition: format_definition(package.definition),
              stereotypes: normalize_stereotypes(package.stereotype),
              classes: collect_class_ids(package),
              sub_packages: collect_sub_package_ids(package),
              diagrams: collect_diagram_ids(package),
              parent: parent_id(package),
            )
          end

          def collect_class_ids(package)
            (package.classes || []).map { |c| @id_generator.class_id(c) }
          end

          def collect_sub_package_ids(package)
            (package.packages || []).map { |p| @id_generator.package_id(p) }
          end

          def collect_diagram_ids(package)
            package_diagrams(package).map { |d| @id_generator.diagram_id(d) }
          end

          def parent_id(package)
            return nil unless package.namespace.is_a?(Lutaml::Uml::Package)

            @id_generator.package_id(package.namespace)
          end

          def package_path(package)
            return package.name unless package.namespace
            return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

            "#{package_path(package.namespace)}::#{package.name}"
          end

          def package_diagrams(package)
            return [] unless @options[:include_diagrams]

            package.diagrams || []
          rescue StandardError => e
            warn "Error getting diagrams for #{package.name}: #{e.message}"
            []
          end
        end
      end
    end
  end
end
