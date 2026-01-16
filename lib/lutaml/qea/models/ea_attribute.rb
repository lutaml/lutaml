# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents an attribute from the t_attribute table in EA database
      # This represents class attributes/properties
      class EaAttribute < BaseModel
        attribute :ea_object_id, Lutaml::Model::Type::Integer
        attribute :name, Lutaml::Model::Type::String
        attribute :scope, Lutaml::Model::Type::String
        attribute :stereotype, Lutaml::Model::Type::String
        attribute :containment, Lutaml::Model::Type::String
        attribute :isstatic, Lutaml::Model::Type::Integer
        attribute :iscollection, Lutaml::Model::Type::Integer
        attribute :isordered, Lutaml::Model::Type::Integer
        attribute :allowduplicates, Lutaml::Model::Type::Integer
        attribute :lowerbound, Lutaml::Model::Type::String
        attribute :upperbound, Lutaml::Model::Type::String
        attribute :container, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String
        attribute :derived, Lutaml::Model::Type::String
        attribute :id, Lutaml::Model::Type::Integer
        attribute :pos, Lutaml::Model::Type::Integer
        attribute :genoption, Lutaml::Model::Type::String
        attribute :length, Lutaml::Model::Type::Integer
        attribute :precision, Lutaml::Model::Type::Integer
        attribute :scale, Lutaml::Model::Type::Integer
        attribute :const, Lutaml::Model::Type::Integer
        attribute :style, Lutaml::Model::Type::String
        attribute :classifier, Lutaml::Model::Type::String
        attribute :default, Lutaml::Model::Type::String
        attribute :type, Lutaml::Model::Type::String
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :styleex, Lutaml::Model::Type::String

        def self.primary_key_column
          :id
        end

        def self.table_name
          "t_attribute"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaAttribute, nil] New instance or nil if row is nil
        def self.from_db_row(row) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return nil if row.nil?

          new(
            ea_object_id: row["Object_ID"],
            name: row["Name"],
            scope: row["Scope"],
            stereotype: row["Stereotype"],
            containment: row["Containment"],
            isstatic: row["IsStatic"],
            iscollection: row["IsCollection"],
            isordered: row["IsOrdered"],
            allowduplicates: row["AllowDuplicates"],
            lowerbound: row["LowerBound"],
            upperbound: row["UpperBound"],
            container: row["Container"],
            notes: row["Notes"],
            derived: row["Derived"],
            id: row["ID"],
            pos: row["Pos"],
            genoption: row["GenOption"],
            length: row["Length"],
            precision: row["Precision"],
            scale: row["Scale"],
            const: row["Const"],
            style: row["Style"],
            classifier: row["Classifier"],
            default: row["Default"],
            type: row["Type"],
            ea_guid: row["ea_guid"],
            styleex: row["StyleEx"],
          )
        end

        # Check if attribute is static
        # @return [Boolean]
        def static?
          isstatic == 1
        end

        # Check if attribute is a collection
        # @return [Boolean]
        def collection?
          iscollection == 1
        end

        # Check if attribute is ordered
        # @return [Boolean]
        def ordered?
          isordered == 1
        end

        # Check if attribute allows duplicates
        # @return [Boolean]
        def allow_duplicates?
          allowduplicates == 1
        end

        # Check if attribute is constant
        # @return [Boolean]
        def constant?
          const == 1
        end

        # Check if attribute is public
        # @return [Boolean]
        def public?
          scope&.downcase == "public"
        end

        # Check if attribute is private
        # @return [Boolean]
        def private?
          scope&.downcase == "private"
        end

        # Check if attribute is protected
        # @return [Boolean]
        def protected?
          scope&.downcase == "protected"
        end
      end
    end
  end
end
