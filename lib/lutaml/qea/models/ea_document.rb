# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a document from the t_document table in EA database
      # Stores documentation style templates and artifacts
      class EaDocument < BaseModel
        attribute :doc_id, Lutaml::Model::Type::String
        attribute :doc_name, Lutaml::Model::Type::String
        attribute :doc_type, Lutaml::Model::Type::String
        attribute :str_content, Lutaml::Model::Type::String
        attribute :bin_content, Lutaml::Model::Type::String
        attribute :element_id, Lutaml::Model::Type::String

        def self.primary_key_column
          :doc_id
        end

        def self.table_name
          "t_document"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaDocument, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            doc_id: row["DocID"],
            doc_name: row["DocName"],
            doc_type: row["DocType"],
            str_content: row["StrContent"],
            bin_content: row["BinContent"],
            element_id: row["ElementID"],
          )
        end

        # Convenience aliases
        alias_method :id, :doc_id
        alias_method :name, :doc_name
        alias_method :type, :doc_type

        # Check if this is a style document
        # @return [Boolean]
        def style_document?
          doc_type == "SSDOCSTYLE"
        end

        # Check if document has string content
        # @return [Boolean]
        def has_content?
          !str_content.nil? && !str_content.empty?
        end

        # Check if document has binary content
        # @return [Boolean]
        def has_binary_content?
          !bin_content.nil? && !bin_content.empty?
        end
      end
    end
  end
end