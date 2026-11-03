# frozen_string_literal: true

module Expressir
  module Changes
    # Represents a mapping change entry
    class MappingChange < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :description, :string

      yaml do
        map "name", to: :name
        map "description", to: :description
      end
    end
  end
end
