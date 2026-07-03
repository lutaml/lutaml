# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class PackageSerializer < Base
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
              path: package_path_for(package),
              definition: format_definition(package.definition, @options),
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
        end
      end
    end
  end
end
