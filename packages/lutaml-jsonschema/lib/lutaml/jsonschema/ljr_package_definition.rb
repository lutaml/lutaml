# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # LJR = LutaML JSON Schema Repository.
    # Defines the package layout: Schema models in separate JSON files,
    # Configuration in a single lutaml-jsonschema.yaml file.
    module LjrPackageDefinition
      def self.definition
        @definition ||= Lutaml::Store::PackageDefinition.new(
          name: :ljr,
        ) do |pkg|
          pkg.model(
            model: Schema,
            dir: nil,
            layout: :separate,
            key: :dollar_id,
            default_format: :json,
          )
          pkg.model(
            model: Configuration,
            file: "lutaml-jsonschema.yaml",
            key: :title,
            default_format: :yaml,
          )
        end
      end
    end
  end
end
