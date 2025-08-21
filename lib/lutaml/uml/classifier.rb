# frozen_string_literal: true

module Lutaml
  module Uml
    class Classifier < TopElement
      attribute :generalization, :string, collection: true, default: -> { [] }

      yaml do
        map "generalization", to: :generalization
      end
    end
  end
end
