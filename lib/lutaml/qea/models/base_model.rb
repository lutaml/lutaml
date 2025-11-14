# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Qea
    module Models
      # Abstract base model for all QEA database models
      # Provides common behavior and interface for domain models
      class BaseModel < Lutaml::Model::Serializable
        # Abstract method to be implemented by subclasses
        # @return [Symbol] the primary key column name
        def self.primary_key_column
          raise NotImplementedError,
                "#{self} must implement .primary_key_column"
        end

        # Abstract method to be implemented by subclasses
        # @return [String] the database table name
        def self.table_name
          raise NotImplementedError,
                "#{self} must implement .table_name"
        end

        # Returns the primary key value for this instance
        # @return [Object] the primary key value
        def primary_key
          send(self.class.primary_key_column)
        end

        # Create instance from database row hash
        # Handles case-insensitive column name mapping from database
        # @param row [Hash] database row with string keys
        # @return [BaseModel] new instance
        def self.from_db_row(row)
          return nil if row.nil?

          # Convert database column names to attribute names
          attrs = row.transform_keys do |key|
            key.to_s.downcase.to_sym
          end

          new(attrs)
        end
      end
    end
  end
end
