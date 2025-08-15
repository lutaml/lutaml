# frozen_string_literal: true

module Lutaml
  module Uml
    class Group < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :values, :string, collection: true
      attribute :groups, Group, collection: true

      yaml do
        map "id", to: :id
        map "values", to: :values
        map "groups", to: :groups
      end
    end
  end
end
