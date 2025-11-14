# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents an object type definition from t_objecttypes table
      #
      # This table provides reference data for object/class types available
      # in EA. These define what kinds of UML elements can be created.
      #
      # @example
      #   object_type = EaObjectType.new
      #   object_type.object_type #=> "Class"
      #   object_type.description #=> "UML Class"
      #   object_type.design_object? #=> false
      class EaObjectType < BaseModel
        attribute :object_type, Lutaml::Model::Type::String
        attribute :description, Lutaml::Model::Type::String
        attribute :designobject, Lutaml::Model::Type::Integer
        attribute :imageid, Lutaml::Model::Type::Integer

        def self.table_name
          "t_objecttypes"
        end

        # Primary key is Object_Type (text)
        def self.primary_key_column
          "Object_Type"
        end

        # Friendly name for object type
        # @return [String]
        def name
          object_type
        end

        # Check if this is a design object
        # @return [Boolean]
        def design_object?
          designobject == 1
        end

        # Alias for readability
        alias design_object designobject
        alias image_id imageid

        # Check if this is a Class type
        # @return [Boolean]
        def class_type?
          object_type == "Class"
        end

        # Check if this is an Interface type
        # @return [Boolean]
        def interface_type?
          object_type == "Interface"
        end

        # Check if this is a Package type
        # @return [Boolean]
        def package_type?
          object_type == "Package"
        end

        # Check if this is an Actor type
        # @return [Boolean]
        def actor_type?
          object_type == "Actor"
        end
      end
    end
  end
end
