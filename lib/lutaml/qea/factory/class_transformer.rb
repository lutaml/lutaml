# frozen_string_literal: true

require_relative "base_transformer"
require_relative "attribute_transformer"
require_relative "operation_transformer"
require_relative "constraint_transformer"
require_relative "tagged_value_transformer"
require_relative "object_property_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA objects (Class type) to UML classes
      class ClassTransformer < BaseTransformer
        # Transform EA object to UML class
        # @param ea_object [EaObject] EA object model
        # @return [Lutaml::Uml::Class] UML class
        def transform(ea_object)
          return nil if ea_object.nil?
          return nil unless ea_object.uml_class? || ea_object.interface?

          Lutaml::Uml::Class.new.tap do |klass|
            # Map basic properties
            klass.name = ea_object.name
            klass.xmi_id = ea_object.ea_guid
            klass.is_abstract = ea_object.abstract?
            klass.visibility = map_visibility(ea_object.visibility)

            # Map stereotype
            if ea_object.stereotype && !ea_object.stereotype.empty?
              klass.stereotype = [ea_object.stereotype]
            end

            # Add "interface" stereotype if it's an interface
            if ea_object.interface?
              klass.stereotype ||= []
              klass.stereotype << "interface" unless
                klass.stereotype.include?("interface")
            end

            # Map definition/notes
            klass.definition = ea_object.note unless
              ea_object.note.nil? || ea_object.note.empty?

            # Load and transform attributes
            klass.attributes = load_attributes(ea_object.ea_object_id)

            # Load and transform operations
            klass.operations = load_operations(ea_object.ea_object_id)

            # Load and transform constraints
            klass.constraints = load_constraints(ea_object.ea_object_id)

            # Load and transform tagged values
            klass.tagged_values = load_tagged_values(ea_object.ea_guid)

            # Load and transform object properties (as additional tagged values)
            klass.tagged_values.concat(load_object_properties(ea_object.ea_object_id))
          end
        end

        private

        # Load and transform attributes for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::TopElementAttribute>] UML attributes
        def load_attributes(object_id)
          return [] if object_id.nil?

          # Query t_attribute table
          query = "SELECT * FROM t_attribute WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          ea_attributes = rows.map do |row|
            Models::EaAttribute.from_db_row(row)
          end

          # Transform to UML attributes
          attribute_transformer = AttributeTransformer.new(database)
          attribute_transformer.transform_collection(ea_attributes)
        end

        # Load and transform operations for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Operation>] UML operations
        def load_operations(object_id)
          return [] if object_id.nil?

          # Query t_operation table
          query = "SELECT * FROM t_operation WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          ea_operations = rows.map do |row|
            Models::EaOperation.from_db_row(row)
          end

          # Transform to UML operations
          operation_transformer = OperationTransformer.new(database)
          operation_transformer.transform_collection(ea_operations)
        end

        # Load and transform constraints for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Constraint>] UML constraints
        def load_constraints(object_id)
          return [] if object_id.nil?
          return [] unless database.object_constraints

          # Filter constraints for this object from the in-memory collection
          ea_constraints = database.object_constraints.select do |c|
            c.ea_object_id == object_id
          end

          # Transform to UML constraints
          constraint_transformer = ConstraintTransformer.new(database)
          constraint_transformer.transform_collection(ea_constraints)
        end

        # Load and transform tagged values for a class
        # @param ea_guid [String] Element GUID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_tagged_values(ea_guid)
          return [] if ea_guid.nil?
          return [] unless database.tagged_values

          # Filter tagged values for this element from the in-memory collection
          ea_tags = database.tagged_values.select do |tag|
            tag.element_id == ea_guid
          end

          # Transform to UML tagged values
          tag_transformer = TaggedValueTransformer.new(database)
          tag_transformer.transform_collection(ea_tags)
        end

        # Load and transform object properties for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_object_properties(object_id)
          return [] if object_id.nil?
          return [] unless database.object_properties

          # Filter object properties for this object from the in-memory
          # collection
          ea_props = database.object_properties.select do |prop|
            prop.ea_object_id == object_id
          end

          # Transform to UML tagged values
          prop_transformer = ObjectPropertyTransformer.new(database)
          prop_transformer.transform_collection(ea_props)
        end
      end
    end
  end
end
