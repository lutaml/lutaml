# frozen_string_literal: true

module Lutaml
  module Uml
    class Cardinality < Lutaml::Model::Serializable
      skip_reference_registration

      attribute :min, :string
      attribute :max, :string
    end
  end
end
