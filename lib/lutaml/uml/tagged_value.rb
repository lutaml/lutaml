# frozen_string_literal: true

module Lutaml
  module Uml
    # Represents a tagged value (custom metadata) in UML
    #
    # Tagged values are name-value pairs that provide additional metadata
    # for UML elements beyond the standard UML metamodel.
    class TaggedValue < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :value, :string
      attribute :notes, :string

      yaml do
        map "name", to: :name
        map "value", to: :value
        map "notes", to: :notes
      end
    end
  end
end
