# frozen_string_literal: true

module Expressir
  class SchemaManifestEntry < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :path, :string
    # attribute :schemas_only, :boolean

    # container_path is a copy of Expressir::SchemaManifest.path,
    # used to resolve the path of each schema within
    # Expressir::SchemaManifest.schemas,
    # when Expressir::SchemaManifest.schemas is recursively flattened
    attr_accessor :container_path
  end
end
