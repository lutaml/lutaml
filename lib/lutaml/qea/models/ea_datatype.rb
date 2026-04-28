# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a data type definition from t_datatypes table
      #
      # This table stores database-specific type definitions and mappings.
      # It maps database vendor types (e.g., "VARCHAR2" in Oracle) to
      # generic types (e.g., "varchar"). This is metadata for database
      # schema generation, not UML DataType instances.
      #
      # @example
      #   datatype = EaDatatype.new
      #   datatype.type #=> "DDL"
      #   datatype.product_name #=> "Oracle"
      #   datatype.data_type #=> "VARCHAR2"
      #   datatype.generic_type #=> "varchar"
      class EaDatatype < BaseModel
        attribute :type, Lutaml::Model::Type::String
        attribute :productname, Lutaml::Model::Type::String
        attribute :datatype, Lutaml::Model::Type::String
        attribute :size, Lutaml::Model::Type::Integer
        attribute :maxlen, Lutaml::Model::Type::Integer
        attribute :maxprec, Lutaml::Model::Type::Integer
        attribute :maxscale, Lutaml::Model::Type::Integer
        attribute :defaultlen, Lutaml::Model::Type::Integer
        attribute :defaultprec, Lutaml::Model::Type::Integer
        attribute :defaultscale, Lutaml::Model::Type::Integer
        attribute :user, Lutaml::Model::Type::Integer
        attribute :pdata1, Lutaml::Model::Type::String
        attribute :pdata2, Lutaml::Model::Type::String
        attribute :pdata3, Lutaml::Model::Type::String
        attribute :pdata4, Lutaml::Model::Type::String
        attribute :haslength, Lutaml::Model::Type::String
        attribute :generictype, Lutaml::Model::Type::String
        attribute :datatypeid, Lutaml::Model::Type::Integer

        def self.table_name
          "t_datatypes"
        end

        def self.primary_key_column
          :datatypeid
        end

        # Check if this is a DDL type
        # @return [Boolean]
        def ddl_type?
          type == "DDL"
        end

        # Check if this is a Code type
        # @return [Boolean]
        def code_type?
          type == "Code"
        end

        # Check if this is a user-defined type
        # @return [Boolean]
        def user_defined?
          user == 1
        end

        # Check if type has length parameter
        # @return [Boolean]
        def has_length?
          size == 1 || !haslength.nil?
        end

        # Check if type has precision parameter
        # @return [Boolean]
        def has_precision?
          size == 2
        end

        # Get full type signature with size/precision
        # @return [String]
        def type_signature
          case size
          when 1
            "#{datatype}(#{defaultlen})"
          when 2
            "#{datatype}(#{defaultprec},#{defaultscale})"
          else
            datatype
          end
        end

        # Aliases for readability
        alias product_name productname
        alias data_type datatype
        alias max_len maxlen
        alias max_prec maxprec
        alias max_scale maxscale
        alias default_len defaultlen
        alias default_prec defaultprec
        alias default_scale defaultscale
        alias generic_type generictype
        alias datatype_id datatypeid
      end
    end
  end
end
