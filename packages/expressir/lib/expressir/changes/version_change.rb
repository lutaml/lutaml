# frozen_string_literal: true

module Expressir
  module Changes
    # Represents a version version of schema changes
    class VersionChange < Lutaml::Model::Serializable
      attribute :version, :integer
      attribute :description, :string
      attribute :additions, ItemChange, collection: true
      attribute :modifications, ItemChange, collection: true
      attribute :deletions, ItemChange, collection: true
      attribute :mappings, MappingChange, collection: true
      attribute :changes, MappingChange, collection: true

      yaml do
        map "version", to: :version
        map "description", to: :description
        map "additions", to: :additions
        map "modifications", to: :modifications
        map "deletions", to: :deletions
        map "mappings", to: :mappings
        map "changes", to: :changes
      end
    end
  end
end
