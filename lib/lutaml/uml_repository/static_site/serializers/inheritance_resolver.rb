# frozen_string_literal: true

require "set"
require_relative "../../../uml/model_helpers"
require_relative "../../class_lookup_index"

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
            parent_xmi_ids = @generalization_map[klass.xmi_id]

            if parent_xmi_ids && !parent_xmi_ids.empty?
              parents = parent_xmi_ids.filter_map do |parent_xmi_id|
                next if parent_xmi_id == klass.xmi_id
                parent = class_lookup.by_xmi_id(parent_xmi_id)
                parent ? @id_generator.class_id(parent) : nil
              end
              return parents unless parents.empty?
            end

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
            unless klass.respond_to?(:generalization) && klass.generalization
              return []
            end
            return [] if visited.include?(klass.xmi_id)

            visited.add(klass.xmi_id)
            inherited = []
            current_gen = klass.generalization
            parent_order = 0

            while current_gen
              parent_class = class_lookup.by_xmi_id(current_gen.general_id)
              break unless parent_class
              break if visited.include?(parent_class.xmi_id)

              visited.add(parent_class.xmi_id)

              if parent_class.attributes
                sorted_attrs = parent_class.attributes.sort_by { |a| a.name || "" }
                sorted_attrs.each do |attr|
                  attr_id = @id_generator.attribute_id(attr, parent_class)
                  inherited << {
                    attributeId: attr_id,
                    attribute: serialize_attribute(attr, parent_class, attr_id),
                    inheritedFrom: @id_generator.class_id(parent_class),
                    inheritedFromName: parent_class.name,
                    parentOrder: parent_order,
                  }
                end
              end

              parent_order += 1
              current_gen = current_gen.general if current_gen.respond_to?(:general)
            end

            inherited
          rescue StandardError => e
            warn "Error computing inherited attributes: #{e.message}"
            []
          end

          def compute_inherited_associations(klass, visited = Set.new)
            unless klass.respond_to?(:generalization) && klass.generalization
              return []
            end
            return [] if visited.include?(klass.xmi_id)

            visited.add(klass.xmi_id)
            inherited = []
            current_gen = klass.generalization
            parent_order = 0

            while current_gen
              parent_class = class_lookup.by_xmi_id(current_gen.general_id)
              break unless parent_class
              break if visited.include?(parent_class.xmi_id)

              visited.add(parent_class.xmi_id)
              parent_associations = find_class_associations(parent_class)

              assoc_with_roles = parent_associations.filter_map do |assoc_id|
                assoc = @repository.associations_index.find do |a|
                  @id_generator.association_id(a) == assoc_id
                end
                next unless assoc

                local_role = if assoc.owner_end_xmi_id == parent_class.xmi_id
                               assoc.owner_end_attribute_name || assoc.owner_end || ""
                             elsif assoc.member_end_xmi_id == parent_class.xmi_id
                               assoc.member_end_attribute_name || assoc.member_end || ""
                             else
                               ""
                             end
                { id: assoc_id, role: local_role }
              end

              assoc_with_roles.sort_by { |a| a[:role] }.each do |item|
                inherited << {
                  associationId: item[:id],
                  inheritedFrom: @id_generator.class_id(parent_class),
                  inheritedFromName: parent_class.name,
                  parentOrder: parent_order,
                  localRole: item[:role],
                }
              end

              parent_order += 1
              current_gen = current_gen.general if current_gen.respond_to?(:general)
            end

            inherited
          rescue StandardError => e
            warn "Error computing inherited associations: #{e.message}"
            []
          end

          def serialize_generalization(klass, visited = Set.new)
            unless klass.respond_to?(:generalization) && klass.generalization
              return nil
            end
            return nil if visited.include?(klass.xmi_id)

            visited.add(klass.xmi_id)
            gen = klass.generalization

            {
              generalId: gen.general_id,
              generalName: gen.general_name,
              generalUpperKlass: gen.respond_to?(:general_upper_klass) ? gen.general_upper_klass : nil,
              hasGeneral: gen.respond_to?(:has_general) ? gen.has_general : false,
              name: gen.name,
              type: gen.type,
              definition: format_definition(gen.definition),
              stereotype: gen.respond_to?(:stereotype) ? gen.stereotype : nil,
              ownedProps: serialize_general_attrs(gen, :owned_props),
              assocProps: serialize_general_attrs(gen, :assoc_props),
              inheritedProps: serialize_general_attrs(gen, :inherited_props),
              inheritedAssocProps: serialize_general_attrs(gen, :inherited_assoc_props),
            }
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
              upperKlass: attr.respond_to?(:upper_klass) ? attr.upper_klass : nil,
              nameNs: attr.respond_to?(:name_ns) ? attr.name_ns : nil,
              typeNs: attr.respond_to?(:type_ns) ? attr.type_ns : nil,
            }
          end

          private

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
            {
              id: id,
              name: attribute.name,
              type: attribute.type,
              visibility: attribute.visibility,
              owner: @id_generator.class_id(owner),
              ownerName: owner.name,
              cardinality: serialize_cardinality(attribute.cardinality),
              definition: format_definition(attribute.definition),
              stereotypes: normalize_stereotypes(
                attribute.respond_to?(:stereotype) ? attribute.stereotype : nil,
              ),
              isStatic: attribute.respond_to?(:is_static) ? attribute.is_static : false,
              isReadOnly: attribute.respond_to?(:is_read_only) ? attribute.is_read_only : false,
              defaultValue: attribute.respond_to?(:default) ? attribute.default : nil,
            }
          end

          def serialize_general_attrs(gen, method)
            return [] unless gen.respond_to?(method)
            (gen.send(method) || []).map { |attr| serialize_general_attribute(attr) }
          end

          def serialize_cardinality(cardinality)
            return nil unless cardinality

            {
              min: cardinality.min,
              max: cardinality.max,
            }
          end

          def format_definition(definition)
            return nil if definition.nil? || definition.empty?
            formatted = definition.strip
            if @options[:max_definition_length] &&
                formatted.length > @options[:max_definition_length]
              formatted = "#{formatted[0...@options[:max_definition_length]]}..."
            end
            if @options[:format_definitions]
              formatted = formatted.gsub(%r{(https?://[^\s]+)}, '[\1](\1)')
            end
            formatted
          end
        end
      end
    end
  end
end
