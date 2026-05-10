# frozen_string_literal: true

require_relative "top_element"
require_relative "association_generalization"
require_relative "operation"

module Lutaml
  module Uml
    class Classifier < TopElement
      attribute :association_generalization,
                ::Lutaml::Uml::AssociationGeneralization,
                collection: true, default: -> { [] }
      attribute :operations, Operation, collection: true, default: -> { [] }
      attribute :is_abstract, :boolean, default: false

      yaml do
        map "generalization", to: :association_generalization
      end
    end
  end
end
