# frozen_string_literal: true

module Expressir
  module Eengine
    # Represents a modified EXPRESS object in an Eengine comparison report
    class ModifiedObject < Lutaml::Model::Serializable
      attribute :type, :string
      attribute :name, :string
      attribute :interfaced_items, :string
      attribute :description, :string
      # Semantic change classification (TODO.compat/06): breaking or
      # additive, per the subtype graph and the ISO 10303-11 Annex K
      # deprecation policy. Optional — readers that ignore unknown
      # attributes are unaffected.
      attribute :classif, :string

      xml do
        element "modified.object"
        map_attribute "type", to: :type
        map_attribute "name", to: :name
        map_attribute "interfaced.items", to: :interfaced_items
        map_attribute "classif", to: :classif
        map_element "description", to: :description
      end
    end
  end
end
