# frozen_string_literal: true

module Lutaml
  module Uml
    class Classifier < TopElement
      skip_reference_registration

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
