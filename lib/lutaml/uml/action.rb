# frozen_string_literal: true

module Lutaml
  module Uml
    class Action < Lutaml::Model::Serializable
      attribute :verb, :string
      attribute :direction, :string

      yaml do
        map "verb", to: :verb
        map "direction", to: :direction
      end
    end
  end
end
