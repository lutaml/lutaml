# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents an operation from the t_operation table in EA database
      # This represents class methods/operations
      class EaOperation < BaseModel
        attribute :operationid, Lutaml::Model::Type::Integer
        attribute :ea_object_id, Lutaml::Model::Type::Integer
        attribute :name, Lutaml::Model::Type::String
        attribute :scope, Lutaml::Model::Type::String
        attribute :type, Lutaml::Model::Type::String
        attribute :returnarray, Lutaml::Model::Type::String
        attribute :stereotype, Lutaml::Model::Type::String
        attribute :isstatic, Lutaml::Model::Type::String
        attribute :concurrency, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String
        attribute :behaviour, Lutaml::Model::Type::String
        attribute :abstract, Lutaml::Model::Type::String
        attribute :genoption, Lutaml::Model::Type::String
        attribute :synchronized, Lutaml::Model::Type::String
        attribute :pos, Lutaml::Model::Type::Integer
        attribute :const, Lutaml::Model::Type::Integer
        attribute :style, Lutaml::Model::Type::String
        attribute :pure, Lutaml::Model::Type::Integer
        attribute :throws, Lutaml::Model::Type::String
        attribute :classifier, Lutaml::Model::Type::String
        attribute :code, Lutaml::Model::Type::String
        attribute :isroot, Lutaml::Model::Type::Integer
        attribute :isleaf, Lutaml::Model::Type::Integer
        attribute :isquery, Lutaml::Model::Type::Integer
        attribute :stateflags, Lutaml::Model::Type::String
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :styleex, Lutaml::Model::Type::String

        def self.primary_key_column
          :operationid
        end

        def self.table_name
          "t_operation"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaOperation, nil] New instance or nil if row is nil
        def self.from_db_row(row) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return nil if row.nil?

          new(
            operationid: row["OperationID"],
            ea_object_id: row["Object_ID"],
            name: row["Name"],
            scope: row["Scope"],
            type: row["Type"],
            returnarray: row["ReturnArray"],
            stereotype: row["Stereotype"],
            isstatic: row["IsStatic"],
            concurrency: row["Concurrency"],
            notes: row["Notes"],
            behaviour: row["Behaviour"],
            abstract: row["Abstract"],
            genoption: row["GenOption"],
            synchronized: row["Synchronized"],
            pos: row["Pos"],
            const: row["Const"],
            style: row["Style"],
            pure: row["Pure"],
            throws: row["Throws"],
            classifier: row["Classifier"],
            code: row["Code"],
            isroot: row["IsRoot"],
            isleaf: row["IsLeaf"],
            isquery: row["IsQuery"],
            stateflags: row["StateFlags"],
            ea_guid: row["ea_guid"],
            styleex: row["StyleEx"],
          )
        end

        # Check if operation is static
        # @return [Boolean]
        def static?
          isstatic == "1"
        end

        # Check if operation is abstract
        # @return [Boolean]
        def abstract?
          abstract == "1"
        end

        # Check if operation is synchronized
        # @return [Boolean]
        def synchronized?
          synchronized == "1"
        end

        # Check if operation is pure virtual
        # @return [Boolean]
        def pure?
          pure == 1
        end

        # Check if operation is a query
        # @return [Boolean]
        def query?
          isquery == 1
        end

        # Check if operation is root
        # @return [Boolean]
        def root?
          isroot == 1
        end

        # Check if operation is leaf
        # @return [Boolean]
        def leaf?
          isleaf == 1
        end

        # Check if operation is constant
        # @return [Boolean]
        def constant?
          const == 1
        end

        # Check if operation is public
        # @return [Boolean]
        def public?
          scope&.downcase == "public"
        end

        # Check if operation is private
        # @return [Boolean]
        def private?
          scope&.downcase == "private"
        end

        # Check if operation is protected
        # @return [Boolean]
        def protected?
          scope&.downcase == "protected"
        end
      end
    end
  end
end
