# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module UmlRepository
    # PackageMetadata holds metadata about a LUR package.
    #
    # This class provides structured metadata that can be embedded in LUR
    # (LutaML UML Repository) packages, including information about the package
    # name, version, publisher, licensing, and other descriptive information.
    #
    # Metadata is stored in the package's metadata.yaml file and can be
    # specified when building packages via CLI or API.
    #
    # @example Creating metadata programmatically
    #   metadata = PackageMetadata.new(
    #     name: "Urban Planning Model",
    #     version: "2.3.0",
    #     publisher: "City Planning Department",
    #     license: "CC-BY-4.0",
    #     description: "UML model for urban planning workflows",
    #     keywords: "urban, planning, infrastructure",
    #     homepage: "https://example.com/urban-model",
    #     authors: ["Jane Doe", "John Smith"],
    #     maintainers: "planning-team@example.com"
    #   )
    #
    # @example Validating metadata
    #   metadata.validate!  # Raises error if name or version missing
    #
    # @example Serializing to YAML
    #   yaml = metadata.to_yaml
    #
    # @example Loading from YAML
    #   metadata = PackageMetadata.from_yaml(yaml_string)
    class PackageMetadata < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :version, :string
      attribute :publisher, :string
      attribute :license, :string
      attribute :description, :string
      attribute :keywords, :string
      attribute :homepage, :string
      attribute :authors, :string, collection: true, default: -> { [] }
      attribute :maintainers, :string
      attribute :serialization_format, :string

      key_value do
        map "name", to: :name
        map "version", to: :version
        map "publisher", to: :publisher
        map "license", to: :license
        map "description", to: :description
        map "keywords", to: :keywords
        map "homepage", to: :homepage
        map "authors", to: :authors
        map "maintainers", to: :maintainers
        map "serialization_format", to: :serialization_format
      end

      # Validate that required fields are present.
      #
      # @return [Array<Lutaml::Model::Error>] Array of validation errors
      def validate(*)
        errors = []
        errors << Lutaml::Model::Error.new("name is required") if name.nil? || name.empty?
        errors << Lutaml::Model::Error.new("version is required") if version.nil? || version.empty?
        errors
      end
    end
  end
end