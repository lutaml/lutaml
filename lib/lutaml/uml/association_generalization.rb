# frozen_string_literal: true

module Lutaml
  module Uml
    class AssociationGeneralization < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :type, :string
      attribute :general, :string

      yaml do
        map "id", to: :id
        map "type", to: :type
        map "general", to: :general
      end
    end
  end
end
