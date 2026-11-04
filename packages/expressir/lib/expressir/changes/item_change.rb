# frozen_string_literal: true

module Expressir
  module Changes
    # Represents a single change to an EXPRESS construct
    class ItemChange < Lutaml::Model::Serializable
      attribute :type, :string
      attribute :name, :string
      attribute :description, :string, collection: true
      attribute :interfaced_items, :string

      yaml do
        map "type", to: :type
        map "name", to: :name
        map "description", to: :description
        map "interfaced_items", to: :interfaced_items
      end
    end
  end
end
