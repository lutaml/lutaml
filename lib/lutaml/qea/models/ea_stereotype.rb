# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a stereotype definition from t_stereotypes table
      #
      # Stereotypes are UML profile extensions that classify elements.
      # This table stores stereotype DEFINITIONS (not instances).
      # Individual elements reference these stereotypes by name.
      #
      # @example
      #   stereotype = EaStereotype.new
      #   stereotype.stereotype #=> "CodeList"
      #   stereotype.applies_to #=> "Class"
      #   stereotype.description #=> "A list of codes"
      class EaStereotype < BaseModel
        attribute :stereotype, Lutaml::Model::Type::String
        attribute :appliesto, Lutaml::Model::Type::String
        attribute :description, Lutaml::Model::Type::String
        attribute :mfenabled, Lutaml::Model::Type::Integer
        attribute :mfpath, Lutaml::Model::Type::String
        attribute :metafile, Lutaml::Model::Type::String
        attribute :style, Lutaml::Model::Type::String
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :visualtype, Lutaml::Model::Type::String

        def self.table_name
          "t_stereotypes"
        end

        # No primary key - this is a lookup/reference table
        def self.primary_key_column
          nil
        end

        # Check if stereotype is enabled for metafile
        # @return [Boolean]
        def metafile_enabled?
          mfenabled == 1
        end

        # Get friendly name for applies_to
        # @return [String]
        def element_type
          appliesto
        end

        # Alias for readability
        alias applies_to appliesto
        alias mf_enabled mfenabled
        alias mf_path mfpath
        alias visual_type visualtype
      end
    end
  end
end
