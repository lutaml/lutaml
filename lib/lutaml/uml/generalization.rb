# frozen_string_literal: true

module Lutaml
  module Uml
    class Generalization < Lutaml::Model::Serializable
      attribute :general_id, :string
      attribute :general_name, :string
      attribute :general_attributes,
                ::Lutaml::Uml::GeneralAttribute,
                collection: true, default: -> { [] }
      attribute :general_upper_klass, :string
      attribute :has_general, :boolean, default: false
      attribute :general, ::Lutaml::Uml::Generalization
      attribute :name, :string
      attribute :type, :string
      attribute :definition, :string
      attribute :stereotype, :string
      attribute :attributes,
                ::Lutaml::Uml::GeneralAttribute,
                collection: true, default: -> { [] }
      attribute :owned_props,
                ::Lutaml::Uml::GeneralAttribute,
                collection: true, default: -> { [] }
      attribute :assoc_props,
                ::Lutaml::Uml::GeneralAttribute,
                collection: true, default: -> { [] }
      attribute :inherited_props,
                ::Lutaml::Uml::GeneralAttribute,
                collection: true, default: -> { [] }
      attribute :inherited_assoc_props,
                ::Lutaml::Uml::GeneralAttribute,
                collection: true, default: -> { [] }
    end
  end
end
