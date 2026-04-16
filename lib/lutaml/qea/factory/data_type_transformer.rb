# frozen_string_literal: true

require_relative "base_transformer"
require_relative "attribute_transformer"
require_relative "operation_transformer"
require_relative "constraint_transformer"
require_relative "tagged_value_transformer"
require_relative "association_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA objects (DataType type) to UML data types
      class DataTypeTransformer < BaseTransformer
        # Transform EA object to UML data type
        # @param ea_object [EaObject] EA object model
        # @return [Lutaml::Uml::DataType] UML data type
        def transform(ea_object) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          return nil if ea_object.nil?
          return nil unless ea_object.data_type?

          Lutaml::Uml::DataType.new.tap do |data_type| # rubocop:disable Metrics/BlockLength
            # Map basic properties
            data_type.name = ea_object.name
            data_type.xmi_id = normalize_guid_to_xmi_format(ea_object.ea_guid,
                                                            "EAID")
            data_type.is_abstract = ea_object.abstract?
            data_type.type = "DataType"
            data_type.visibility = map_visibility(ea_object.visibility)

            # Set package path
            data_type.package_path = calculate_package_path(
              ea_object.package_id,
            )

            # Map stereotype
            if ea_object.stereotype && !ea_object.stereotype.empty?
              data_type.stereotype = ea_object.stereotype
            end

            # Map definition/notes
            data_type.definition = ea_object.note unless
              ea_object.note.nil? || ea_object.note.empty?

            # Load and transform attributes
            attts = load_attributes(ea_object.ea_object_id)
            assoc_attts = load_association_attributes(ea_object.ea_object_id)
            data_type.attributes = attts + assoc_attts

            # Load and transform operations
            data_type.operations = load_operations(ea_object.ea_object_id)

            # Load and transform constraints
            data_type.constraints = load_constraints(ea_object.ea_object_id)

            # Load and transform tagged values
            data_type.tagged_values = load_tagged_values(ea_object.ea_guid)

            # Load associations for this data type
            data_type.associations = load_associations(ea_object.ea_object_id,
                                                       ea_object.ea_guid)
          end
        end

        private

        # Load and transform attributes for a data type
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::TopElementAttribute>] UML attributes
        def load_attributes(object_id)
          return [] if object_id.nil?

          query = "SELECT * FROM t_attribute WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          ea_attributes = rows.map do |row|
            Models::EaAttribute.from_db_row(row)
          end

          attribute_transformer = AttributeTransformer.new(database)
          attribute_transformer.transform_collection(ea_attributes)
        end

        # Load and transform operations for a data type
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Operation>] UML operations
        def load_operations(object_id)
          return [] if object_id.nil?

          query = "SELECT * FROM t_operation WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          ea_operations = rows.map do |row|
            Models::EaOperation.from_db_row(row)
          end

          operation_transformer = OperationTransformer.new(database)
          operation_transformer.transform_collection(ea_operations)
        end

        # Load and transform constraints for a data type
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Constraint>] UML constraints
        def load_constraints(object_id)
          return [] if object_id.nil?
          return [] unless database.object_constraints

          ea_constraints = database.object_constraints.select do |c|
            c.ea_object_id == object_id
          end

          constraint_transformer = ConstraintTransformer.new(database)
          constraint_transformer.transform_collection(ea_constraints)
        end

        # Load and transform tagged values for a data type
        # @param ea_guid [String] Element GUID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_tagged_values(ea_guid)
          return [] if ea_guid.nil?
          return [] unless database.tagged_values

          ea_tags = database.tagged_values.select do |tag|
            tag.element_id == ea_guid
          end

          tag_transformer = TaggedValueTransformer.new(database)
          tag_transformer.transform_collection(ea_tags)
        end

        # Load associations for a data type
        # @param object_id [Integer] Object ID
        # @param object_guid [String] Object GUID
        # @return [Array<Lutaml::Uml::Association>] UML associations
        def load_associations(object_id, object_guid) # rubocop:disable Metrics/MethodLength
          return [] if object_id.nil?

          query = <<-SQL
            SELECT * FROM t_connector
            WHERE Connector_Type = 'Association'
            AND (Start_Object_ID = ? OR End_Object_ID = ?)
          SQL

          rows = database.connection.execute(query, [object_id, object_id])

          assoc_transformer = AssociationTransformer.new(database)
          normalized_xmi_id = normalize_guid_to_xmi_format(object_guid, "EAID")

          rows.filter_map do |row|
            ea_connector = Models::EaConnector.from_db_row(row)
            assoc = assoc_transformer.transform(ea_connector)

            next unless assoc && assoc.owner_end_xmi_id == normalized_xmi_id

            assoc
          end
        end
      end
    end
  end
end
