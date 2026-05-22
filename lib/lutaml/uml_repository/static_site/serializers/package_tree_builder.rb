# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class PackageTreeBuilder < Base
          def build
            root_packages = @repository.document.packages || @repository.packages_index.select do |pkg|
              pkg.namespace.nil? ||
                !pkg.namespace.is_a?(Lutaml::Uml::Package)
            end

            if root_packages.size == 1
              build_tree_node(root_packages.first)
            else
              build_virtual_root(root_packages)
            end
          end

          private

          def build_virtual_root(root_packages)
            Models::SpaPackageTreeNode.new(
              id: "root",
              name: "Model",
              path: "",
              class_count: 0,
              children: root_packages.map { |pkg| build_tree_node(pkg) },
            )
          end

          def build_tree_node(package)
            pkg_id = @id_generator.package_id(package)
            child_nodes = build_child_nodes(package)
            sorted_classes = filter_valid_classes(package.classes || [])
            total_class_count = sorted_classes.size + child_nodes.sum(&:class_count)

            Models::SpaPackageTreeNode.new(
              id: pkg_id,
              name: package.name,
              path: package_path_for(package),
              stereotypes: normalize_stereotypes(package.stereotype),
              class_count: total_class_count,
              classes: build_class_refs(sorted_classes),
              children: child_nodes,
            )
          end

          def build_child_nodes(package)
            sort_by_name(package.packages || []).map do |child|
              build_tree_node(child)
            end
          end

          def sort_by_name(items)
            items.sort_by { |p| p.name || "" }
          end

          def filter_valid_classes(classes)
            classes.reject { |c| c.name.nil? || c.name.empty? }.sort_by(&:name)
          end

          def build_class_refs(classes)
            classes.map do |c|
              Models::SpaTreeClassRef.new(
                id: @id_generator.class_id(c),
                name: c.name,
                stereotypes: normalize_stereotypes(c.stereotype),
              )
            end
          end
        end
      end
    end
  end
end
