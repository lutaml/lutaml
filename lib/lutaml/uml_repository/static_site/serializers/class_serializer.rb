# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class ClassSerializer < Base
          def initialize(repository, id_generator, options,
inheritance_resolver)
            super(repository, id_generator, options)
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

          def serialize(klass, id)
            Models::SpaClass.new(
              id: id,
              xmi_id: klass.xmi_id,
              name: klass.name,
              qualified_name: qualified_name_for(klass),
              type: class_type_for(klass),
              package: package_id_for_class(klass),
              stereotypes: normalize_stereotypes(klass.stereotype),
              definition: format_definition(klass.definition, @options),
              attributes: serialize_attribute_ids(klass),
              operations: serialize_class_operations(klass),
              associations: sort_associations(find_class_associations(klass),
                                              klass),
              is_abstract: klass.is_abstract,
              literals: serialize_literals(klass),
              **inheritance_data(klass),
            )
          end

          def inheritance_data(klass)
            {
              generalizations: @inheritance_resolver.find_generalizations(klass),
              specializations: @inheritance_resolver.find_specializations(klass),
              inherited_attributes: @inheritance_resolver.compute_inherited_attributes(klass),
              inherited_associations: @inheritance_resolver.compute_inherited_associations(klass),
            }
          end

          def serialize_attribute_ids(klass)
            (klass.attributes || []).sort_by { |a| a.name || "" }
              .map { |attr| @id_generator.attribute_id(attr, klass) }
          end

          def serialize_class_operations(klass)
            return [] unless klass.operations

            klass.operations.map { |op| @id_generator.operation_id(op, klass) }
          end

          def sort_associations(assoc_ids, klass)
            xmi_id = klass.xmi_id
            assoc_ids.sort_by do |assoc_id|
              assoc = find_assoc_by_id(assoc_id)
              next "" unless assoc

              resolve_assoc_role(assoc, xmi_id)
            end
          end

          def serialize_literals(klass)
            return [] unless klass.is_a?(Lutaml::Uml::Enum) && klass.owned_literal

            klass.owned_literal.map do |literal|
              Models::SpaLiteral.new(
                name: literal.name,
                definition: format_definition(literal.definition, @options),
              )
            end
          rescue StandardError
            []
          end

          def package_id_for_class(klass)
            return nil unless klass.namespace.is_a?(Lutaml::Uml::Package)

            @id_generator.package_id(klass.namespace)
          end
        end
      end
    end
  end
end
