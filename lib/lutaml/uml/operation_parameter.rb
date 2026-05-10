# frozen_string_literal: true

module Lutaml
  module Uml
    class OperationParameter < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :type, :string
      attribute :direction, :string, default: "in"

      yaml do
        map "name", to: :name
        map "type", to: :type
        map "direction", to: :direction
      end
    end
  end
end
