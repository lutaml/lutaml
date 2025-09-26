# frozen_string_literal: true

module Lutaml
  module Uml
    class Classifier < TopElement
      attribute :association_generalization,
                ::Lutaml::Uml::AssociationGeneralization,
                collection: true, default: -> { [] }

      yaml do
        map "generalization", to: :association_generalization
      end
    end
  end
end
