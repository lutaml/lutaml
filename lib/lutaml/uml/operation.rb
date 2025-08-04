# frozen_string_literal: true

module Lutaml
  module Uml
    class Operation < TopElement
      attribute :return_type, :string
      attribute :parameter_type, :string

      yaml do
        map "return_type", to: :return_type
        map "parameter_type", to: :parameter_type
      end
    end
  end
end
