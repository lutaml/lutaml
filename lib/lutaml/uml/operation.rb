# frozen_string_literal: true

module Lutaml
  module Uml
    class Operation < TopElement
      skip_reference_registration

      attribute :id, :string
      attribute :return_type, :string
      attribute :parameter_type, :string
      attribute :is_static, :boolean, default: false
      attribute :is_abstract, :boolean, default: false
      attribute :owned_parameter, OperationParameter, collection: true,
                                                      default: -> { [] }

      yaml do
        map "id", to: :id
        map "return_type", to: :return_type
        map "parameter_type", to: :parameter_type
      end
    end
  end
end
