# frozen_string_literal: true

module Lutaml
  module Uml
    class Fontname < Lutaml::Model::Serializable
      attribute :name, :string

      yaml do
        map "name", to: :name
      end
    end
  end
end
