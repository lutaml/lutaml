# frozen_string_literal: true

module Lutaml
  module Uml
    class Cardinality < Lutaml::Model::Serializable
      attribute :min, :string
      attribute :max, :string
    end
  end
end
