# frozen_string_literal: true

module Lutaml
  module Uml
    class Instance < TopElement
      attribute :classifier, :string
      attribute :slot, :string, collection: true, default: -> { [] }

      yaml do
        map "classifier", to: :classifier
        map "slot", to: :slot
      end
    end
  end
end
