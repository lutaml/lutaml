# frozen_string_literal: true

module Lutaml
  module Uml
    class NameSpace < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :namespace, NameSpace
    end
  end
end
