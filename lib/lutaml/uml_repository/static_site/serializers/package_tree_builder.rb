# frozen_string_literal: true

require_relative "../../../uml/model_helpers"
require_relative "../models/spa_package_tree_node"
require_relative "../models/spa_tree_class_ref"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class PackageTreeBuilder
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator)
            @repository = repository
            @id_generator = id_generator
          end

          def build
            root_packages = if @repository.document.packages
                              @repository.document.packages
                            else
                              @repository.packages_index.select do |pkg|
                                pkg.namespace.nil? ||
                                  !pkg.namespace.is_a?(Lutaml::Uml::Package)
                              end
                            end

            if root_packages.size == 1
              build_tree_node(root_packages.first)
            else
              Models::SpaPackageTreeNode.new(
                id: "root",
                name: "Model",
                path: "",
                class_count: 0,
                children: root_packages.map { |pkg| build_tree_node(pkg) },
              )
            end
          end

          private

          def build_tree_node(package)
            pkg_id = @id_generator.package_id(package)

            sorted_children = (package.packages || []).sort_by do |p|
              p.name || ""
            end
            sorted_classes = (package.classes || [])
              .reject { |c| c.name.nil? || c.name.empty? }
              .sort_by(&:name)

            child_nodes = sorted_children.map { |child| build_tree_node(child) }

            total_class_count = sorted_classes.size + child_nodes.sum(&:class_count)

            Models::SpaPackageTreeNode.new(
              id: pkg_id,
              name: package.name,
              path: package_path_for(package),
              stereotypes: normalize_stereotypes(package.stereotype),
              class_count: total_class_count,
              classes: sorted_classes.map do |c|
                Models::SpaTreeClassRef.new(
                  id: @id_generator.class_id(c),
                  name: c.name,
                  stereotypes: normalize_stereotypes(c.stereotype),
                )
              end,
              children: child_nodes,
            )
          end

          def package_path_for(package)
            return package.name unless package.namespace
            return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

            "#{package_path_for(package.namespace)}::#{package.name}"
          end
        end
      end
    end
  end
end
