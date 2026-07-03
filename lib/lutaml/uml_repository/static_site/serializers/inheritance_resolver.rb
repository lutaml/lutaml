# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class InheritanceResolver < Base
          def initialize(repository, id_generator, options, generalization_map)
            super(repository, id_generator, options)
            @generalization_map = generalization_map
          end

          def find_generalizations(klass)
            map_parents = generalization_map_parents(klass)
            return map_parents unless map_parents.nil?

            parent = @repository.supertype_of(klass)
            return [] if parent && parent.xmi_id == klass.xmi_id

            parent ? [@id_generator.class_id(parent)] : []
          rescue StandardError => e
            warn "Error finding generalizations for #{klass.name}: #{e.message}"
            []
          end

          def find_specializations(klass)
            children = @repository.subtypes_of(klass)
            children.reject { |child| child.xmi_id == klass.xmi_id }
              .map { |child| @id_generator.class_id(child) }
          rescue StandardError
            []
          end

          def compute_inherited_attributes(klass, visited = Set.new)
            walk_inheritance_chain(klass, visited, :attributes)
          rescue StandardError => e
            warn "Error computing inherited attributes: #{e.message}"
            []
          end

          def compute_inherited_associations(klass, visited = Set.new)
            walk_inheritance_chain(klass, visited, :associations)
          rescue StandardError => e
            warn "Error computing inherited associations: #{e.message}"
            []
          end

          private

          def walk_inheritance_chain(klass, visited, collector_method)
            return [] unless klass.is_a?(Lutaml::Uml::Class) && klass.generalization
            return [] if visited.include?(klass.xmi_id)

            visited.add(klass.xmi_id)
            collect_chain_items(klass.generalization, visited, collector_method)
          end

          def collect_chain_items(starting_gen, visited, collector_type)
            inherited = []
            current_gen = starting_gen
            parent_order = 0

            while current_gen
              parent_class = class_lookup.by_xmi_id(current_gen.general_id)
              break unless parent_class
              break if visited.include?(parent_class.xmi_id)

              visited.add(parent_class.xmi_id)
              inherited.concat(
                collect_items_for(parent_class, parent_order, collector_type),
              )

              parent_order += 1
              current_gen = current_gen.general
            end

            inherited
          end

          def collect_items_for(parent_class, parent_order, collector_type)
            case collector_type
            when :attributes
              parent_inherited_attrs(parent_class, parent_order)
            when :associations
              parent_inherited_assocs(parent_class, parent_order)
            else
              []
            end
          end

          def generalization_map_parents(klass)
            parent_xmi_ids = @generalization_map[klass.xmi_id]
            return nil if parent_xmi_ids.nil? || parent_xmi_ids.empty?

            parents = parent_xmi_ids.filter_map do |parent_xmi_id|
              next if parent_xmi_id == klass.xmi_id

              resolve_parent_class_id(parent_xmi_id)
            end
            parents.empty? ? nil : parents
          end

          def resolve_parent_class_id(parent_xmi_id)
            parent = class_lookup.by_xmi_id(parent_xmi_id)
            parent ? @id_generator.class_id(parent) : nil
          end

          def parent_inherited_attrs(parent_class, parent_order)
            return [] unless parent_class.attributes

            parent_class.attributes.sort_by { |a| a.name || "" }
              .map do |attr|
                attr_id = @id_generator.attribute_id(attr, parent_class)
                Models::SpaInheritedAttribute.new(
                  attribute_id: attr_id,
                  attribute: serialize_attribute(attr, parent_class, attr_id),
                  inherited_from: @id_generator.class_id(parent_class),
                  inherited_from_name: parent_class.name,
                  parent_order: parent_order,
                )
              end
          end

          def parent_inherited_assocs(parent_class, parent_order)
            assoc_with_roles = collect_assoc_roles(parent_class)

            assoc_with_roles.sort_by { |a| a[:role] }.map do |item|
              Models::SpaInheritedAssociation.new(
                association_id: item[:id],
                inherited_from: @id_generator.class_id(parent_class),
                inherited_from_name: parent_class.name,
                parent_order: parent_order,
                local_role: item[:role],
              )
            end
          end

          def collect_assoc_roles(parent_class)
            xmi_id = parent_class.xmi_id
            find_class_associations(parent_class).filter_map do |assoc_id|
              assoc = find_assoc_by_id(assoc_id)
              next unless assoc

              { id: assoc_id, role: resolve_assoc_role(assoc, xmi_id) }
            end
          end
        end
      end
    end
  end
end
