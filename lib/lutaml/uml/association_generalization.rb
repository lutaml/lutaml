# frozen_string_literal: true

module Lutaml
  module Uml
    class AssociationGeneralization < Lutaml::Model::Serializable
      skip_reference_registration

      attribute :id, :string
      attribute :type, :string
      attribute :general, :string
      attribute :parent_object_id, :string

      yaml do
        map "id", to: :id
        map "type", to: :type
        map "general", to: :general
      end
    end
  end
end
