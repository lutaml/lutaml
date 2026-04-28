# frozen_string_literal: true

require_relative "base_transformer"
require_relative "attribute_transformer"
require_relative "operation_transformer"
require_relative "constraint_transformer"
require_relative "tagged_value_transformer"
require_relative "object_property_transformer"
require_relative "stereotype_loader"
require_relative "generalization_builder"
require_relative "association_builder"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      class ClassTransformer < BaseTransformer
        def transform(ea_object)
          return nil if ea_object.nil?

          is_class_type = ea_object.uml_class? || ea_object.interface?
          is_proxy = ea_object.object_type == "ProxyConnector"
          is_text_class = ea_object.object_type == "Text"
          return nil unless is_class_type || is_proxy || is_text_class

          Lutaml::Uml::Class.new.tap do |klass|
            klass.name = ea_object.name
            klass.xmi_id = normalize_guid_to_xmi_format(ea_object.ea_guid,
                                                        "EAID")
            klass.is_abstract = ea_object.abstract?
            klass.type = "Class"
            klass.visibility = map_visibility(ea_object.visibility)

            stereotypes = build_stereotypes(ea_object)
            klass.stereotype = stereotypes unless stereotypes.empty?

            klass.definition = normalize_line_endings(ea_object.note) unless
              ea_object.note.nil? || ea_object.note.empty?

            gen_builder = GeneralizationBuilder.new(database)
            assoc_builder = AssociationBuilder.new(database)

            attrs = load_attributes(ea_object.ea_object_id)
            assoc_attrs = gen_builder.convert_to_top_element_attributes(
              assoc_builder.load_association_attributes(ea_object.ea_object_id),
            )
            klass.attributes = attrs + assoc_attrs

            klass.operations = load_operations(ea_object.ea_object_id)
            klass.constraints = load_constraints(ea_object.ea_object_id)
            klass.tagged_values = load_tagged_values(ea_object.ea_guid)
            klass.tagged_values.concat(
              load_object_properties(ea_object.ea_object_id),
            )

            klass.generalization = gen_builder.load_generalization(
              ea_object.ea_object_id,
            )
            klass.association_generalization = gen_builder
              .load_association_generalizations(ea_object.ea_object_id)

            klass.associations = assoc_builder.load_class_associations(
              ea_object.ea_object_id, ea_object.ea_guid,
            )
          end
        end

        private

        def build_stereotypes(ea_object)
          stereotypes = []
          if ea_object.stereotype && !ea_object.stereotype.empty?
            stereotypes << ea_object.stereotype
          end

          xref_stereotype = StereotypeLoader.new(database)
            .load_from_xref(ea_object.ea_guid)
          if xref_stereotype && !stereotypes.include?(xref_stereotype)
            stereotypes << xref_stereotype
          end

          if ea_object.interface? && !stereotypes.include?("interface")
            stereotypes << "interface"
          end

          stereotypes
        end

        def load_attributes(object_id)
          return [] if object_id.nil?

          ea_attributes = database.attributes_for_object(object_id)
            .sort_by { |a| a.pos || 0 }
          AttributeTransformer.new(database).transform_collection(ea_attributes)
        end

        def load_operations(object_id)
          return [] if object_id.nil?

          ea_operations = database.operations_for_object(object_id)
            .sort_by { |op| op.pos || 0 }
          OperationTransformer.new(database).transform_collection(ea_operations)
        end

        def load_constraints(object_id)
          return [] if object_id.nil?
          return [] unless database.object_constraints

          ea_constraints = database.object_constraints.select do |c|
            c.ea_object_id == object_id
          end
          ConstraintTransformer.new(database).transform_collection(ea_constraints)
        end

        def load_tagged_values(ea_guid)
          return [] if ea_guid.nil?
          return [] unless database.tagged_values

          ea_tags = database.tagged_values.select { |tag| tag.element_id == ea_guid }
          TaggedValueTransformer.new(database).transform_collection(ea_tags)
        end

        def load_object_properties(object_id)
          return [] if object_id.nil?
          return [] unless database.object_properties

          ea_props = database.object_properties.select do |prop|
            prop.ea_object_id == object_id
          end
          ObjectPropertyTransformer.new(database).transform_collection(ea_props)
        end
      end
    end
  end
end
