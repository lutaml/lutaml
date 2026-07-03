# frozen_string_literal: true

module Lutaml
  module Uml
    class Fontname < Lutaml::Model::Serializable
      skip_reference_registration

      attribute :name, :string

      yaml do
        map "name", to: :name
      end
    end
  end
end
