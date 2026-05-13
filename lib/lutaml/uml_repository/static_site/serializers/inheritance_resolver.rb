# frozen_string_literal: true

require_relative "../../../uml/model_helpers"
require_relative "../../class_lookup_index"
require_relative "../models/spa_attribute"
require_relative "../models/spa_cardinality"
require_relative "../models/spa_inherited_attribute"
require_relative "../models/spa_inherited_association"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class InheritanceResolver
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator, options, generalization_map)
            @repository = repository
            @id_generator = id_generator
            @options = options
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

          def serialize_generalization(klass, visited = Set.new)
            return nil unless klass.is_a?(Lutaml::Uml::Class) && klass.generalization
            return nil if visited.include?(klass.xmi_id)

            visited.add(klass.xmi_id)
            gen = klass.generalization

            gen_basic_fields(gen).merge(gen_collection_fields(gen))
          rescue StandardError => e
            warn "Error serializing generalization: #{e.message}"
            nil
          end

          def serialize_general_attribute(attr)
            return nil unless attr

            {
              name: attr.name,
              type: attr.type,
              cardinality: serialize_cardinality(attr.cardinality),
              definition: format_definition(attr.definition),
              upperKlass: attr.upper_klass,
              nameNs: attr.name_ns,
              typeNs: attr.type_ns,
            }
          end

          private

          def walk_inheritance_chain(klass, visited, collector_method)
            return [] unless klass.is_a?(Lutaml::Uml::Class) && klass.generalization
            return [] if visited.include?(klass.xmi_id)

            visited.add(klass.xmi_id)
            collect_chain_items(klass.generalization, visited, collector_method)
          end

          COLLECTOR_METHODS = {
            attributes: :parent_inherited_attrs,
            associations: :parent_inherited_assocs,
          }.freeze

          def collect_chain_items(starting_gen, visited, collector_type)
            inherited = []
            current_gen = starting_gen
            parent_order = 0
            method = COLLECTOR_METHODS.fetch(collector_type)

            while current_gen
              parent_class = class_lookup.by_xmi_id(current_gen.general_id)
              break unless parent_class
              break if visited.include?(parent_class.xmi_id)

              visited.add(parent_class.xmi_id)
              inherited.concat(public_send(method, parent_class,
                                           parent_order))

              parent_order += 1
              current_gen = current_gen.general
            end

            inherited
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
              build_inherited_assoc(item, parent_class, parent_order)
            end
          end

          def collect_assoc_roles(parent_class)
            find_class_associations(parent_class).filter_map do |assoc_id|
              assoc = find_assoc_by_generated_id(assoc_id)
              next unless assoc

              { id: assoc_id, role: resolve_local_role(assoc, parent_class) }
            end
          end

          def find_assoc_by_generated_id(assoc_id)
            @repository.associations_index.find do |a|
              @id_generator.association_id(a) == assoc_id
            end
          end

          def build_inherited_assoc(item, parent_class, parent_order)
            Models::SpaInheritedAssociation.new(
              association_id: item[:id],
              inherited_from: @id_generator.class_id(parent_class),
              inherited_from_name: parent_class.name,
              parent_order: parent_order,
              local_role: item[:role],
            )
          end

          def resolve_local_role(assoc, parent_class)
            role_for_end(assoc, parent_class.xmi_id) || ""
          end

          def role_for_end(assoc, xmi_id)
            if assoc.owner_end_xmi_id == xmi_id
              assoc.owner_end_attribute_name || assoc.owner_end
            elsif assoc.member_end_xmi_id == xmi_id
              assoc.member_end_attribute_name || assoc.member_end
            end
          end

          def class_lookup
            @class_lookup ||= ClassLookupIndex.new(@repository.classes_index)
          end

          def find_class_associations(klass)
            associations = @repository.associations_of(klass)
            associations.map { |assoc| @id_generator.association_id(assoc) }
          rescue StandardError
            []
          end

          def serialize_attribute(attribute, owner, id)
            Models::SpaAttribute.new(
              id: id,
              name: attribute.name,
              type: attribute.type,
              visibility: attribute.visibility,
              owner: @id_generator.class_id(owner),
              owner_name: owner.name,
              cardinality: serialize_cardinality(attribute.cardinality),
              definition: format_definition(attribute.definition),
              stereotypes: normalize_stereotypes(attribute.stereotype),
              is_static: attribute.is_static,
              is_read_only: attribute.is_read_only,
              default_value: attribute.default,
            )
          end

          def serialize_general_collection(items)
            return [] unless items

            items.map { |attr| serialize_general_attribute(attr) }
          end

          def serialize_cardinality(cardinality)
            return nil unless cardinality

            Models::SpaCardinality.new(
              min: cardinality.min,
              max: cardinality.max,
            )
          end

          def gen_basic_fields(gen)
            {
              generalId: gen.general_id,
              generalName: gen.general_name,
              generalUpperKlass: gen.general_upper_klass,
              hasGeneral: gen.has_general,
              name: gen.name,
              type: gen.type,
              definition: format_definition(gen.definition),
              stereotype: gen.stereotype,
            }
          end

          def gen_collection_fields(gen)
            {
              ownedProps: serialize_general_collection(gen.owned_props),
              assocProps: serialize_general_collection(gen.assoc_props),
              inheritedProps: serialize_general_collection(gen.inherited_props),
              inheritedAssocProps: serialize_general_collection(gen.inherited_assoc_props),
            }
          end
        end
      end
    end
  end
end
