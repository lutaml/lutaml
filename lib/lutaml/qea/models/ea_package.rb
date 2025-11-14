# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a package from the t_package table in EA database
      # This represents packages/namespaces in the model
      class EaPackage < BaseModel
        attribute :package_id, Lutaml::Model::Type::Integer
        attribute :name, Lutaml::Model::Type::String
        attribute :parent_id, Lutaml::Model::Type::Integer
        attribute :createddate, Lutaml::Model::Type::String
        attribute :modifieddate, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :xmlpath, Lutaml::Model::Type::String
        attribute :iscontrolled, Lutaml::Model::Type::Integer
        attribute :lastloaddate, Lutaml::Model::Type::String
        attribute :lastsavedate, Lutaml::Model::Type::String
        attribute :version, Lutaml::Model::Type::String
        attribute :protected, Lutaml::Model::Type::Integer
        attribute :pkgowner, Lutaml::Model::Type::String
        attribute :umlversion, Lutaml::Model::Type::String
        attribute :usedtd, Lutaml::Model::Type::Integer
        attribute :logxml, Lutaml::Model::Type::Integer
        attribute :codepath, Lutaml::Model::Type::String
        attribute :namespace, Lutaml::Model::Type::String
        attribute :tpos, Lutaml::Model::Type::Integer
        attribute :packageflags, Lutaml::Model::Type::String
        attribute :batchsave, Lutaml::Model::Type::Integer
        attribute :batchload, Lutaml::Model::Type::Integer

        def self.primary_key_column
          :package_id
        end

        def self.table_name
          "t_package"
        end

        # Check if package is controlled
        # @return [Boolean]
        def controlled?
          iscontrolled == 1
        end

        # Check if package is protected
        # @return [Boolean]
        def protected?
          protected == 1
        end

        # Check if package uses DTD
        # @return [Boolean]
        def use_dtd?
          usedtd == 1
        end

        # Check if package logs XML
        # @return [Boolean]
        def log_xml?
          logxml == 1
        end

        # Check if package is root (has no parent)
        # @return [Boolean]
        def root?
          parent_id.nil? || parent_id.zero?
        end
      end
    end
  end
end
