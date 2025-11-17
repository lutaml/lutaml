# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a script from the t_script table in EA database
      # Stores behavioral scripts and debugging configurations
      class EaScript < BaseModel
        attribute :script_id, Lutaml::Model::Type::Integer
        attribute :script_category, Lutaml::Model::Type::String
        attribute :script_name, Lutaml::Model::Type::String
        attribute :script_author, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String
        attribute :script, Lutaml::Model::Type::String

        def self.primary_key_column
          :script_id
        end

        def self.table_name
          "t_script"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaScript, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            script_id: row["ScriptID"],
            script_category: row["ScriptCategory"],
            script_name: row["ScriptName"],
            script_author: row["ScriptAuthor"],
            notes: row["Notes"],
            script: row["Script"],
          )
        end

        # Convenience aliases
        alias_method :id, :script_id
        alias_method :name, :script_name
        alias_method :category, :script_category
        alias_method :author, :script_author

        # Check if this is a debugging script
        # @return [Boolean]
        def debugging_script?
          script_category == "ScriptDebugging"
        end

        # Check if script has content
        # @return [Boolean]
        def has_content?
          !script.nil? && !script.empty?
        end

        # Check if script has notes
        # @return [Boolean]
        def has_notes?
          !notes.nil? && !notes.empty?
        end
      end
    end
  end
end