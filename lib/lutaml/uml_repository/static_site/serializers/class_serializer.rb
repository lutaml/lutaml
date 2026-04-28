# frozen_string_literal: true

require_relative "../../../uml/model_helpers"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class ClassSerializer
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator, options, inheritance_resolver)
            @repository = repository
            @id_generator = id_generator
            @options = options
            @inheritance_resolver = inheritance_resolver
          end

          def build_map
            classes = {}
            @repository.classes_index.each do |klass|
              id = @id_generator.class_id(klass)
              classes[id] = serialize(klass, id)
            end
            classes
          end

          private

          def serialize(klass, id) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
            class_associations = find_class_associations(klass)
            sorted_associations = sort_associations(class_associations, klass)

            {
              id: id,
              xmiId: klass.xmi_id,
              name: klass.name,
              qualifiedName: qualified_name_for(klass),
              type: class_type_for(klass),
              package: package_id_for_class(klass),
              stereotypes: normalize_stereotypes(
                klass.respond_to?(:stereotype) ? klass.stereotype : nil,
              ),
              definition: format_definition(klass.definition),
              attributes: (klass.attributes || []).sort_by { |a| a.name || "" }
                .map { |attr| @id_generator.attribute_id(attr, klass) },
              operations: serialize_class_operations(klass),
              associations: sorted_associations,
              generalizations: @inheritance_resolver.find_generalizations(klass),
              specializations: @inheritance_resolver.find_specializations(klass),
              isAbstract: klass.respond_to?(:is_abstract) ? klass.is_abstract : false,
              literals: serialize_literals(klass),
              inheritedAttributes: @inheritance_resolver.compute_inherited_attributes(klass),
              inheritedAssociations: @inheritance_resolver.compute_inherited_associations(klass),
            }
          end

          def find_class_associations(klass)
            associations = @repository.associations_of(klass)
            associations.map { |assoc| @id_generator.association_id(assoc) }
          rescue StandardError
            []
          end

          def sort_associations(assoc_ids, klass)
            assoc_ids.sort_by do |assoc_id|
              assoc = @repository.associations_index.find do |a|
                @id_generator.association_id(a) == assoc_id
              end
              next "" unless assoc

              if assoc.owner_end_xmi_id == klass.xmi_id
                assoc.owner_end_attribute_name || assoc.owner_end || ""
              elsif assoc.member_end_xmi_id == klass.xmi_id
                assoc.member_end_attribute_name || assoc.member_end || ""
              else
                ""
              end
            end
          end

          def serialize_class_operations(klass)
            return [] unless klass.respond_to?(:operations) && klass.operations
            klass.operations.map { |op| @id_generator.operation_id(op, klass) }
          end

          def serialize_literals(klass)
            return [] unless klass.is_a?(Lutaml::Uml::Enum) && klass.owned_literal

            klass.owned_literal.map do |literal|
              { name: literal.name, definition: format_definition(literal.definition) }
            end
          rescue StandardError
            []
          end

          def package_id_for_class(klass)
            ns = klass.respond_to?(:namespace) ? klass.namespace : nil
            return nil unless ns.is_a?(Lutaml::Uml::Package)
            @id_generator.package_id(ns)
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
