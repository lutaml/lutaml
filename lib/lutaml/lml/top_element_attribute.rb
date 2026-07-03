# frozen_string_literal: true

require "lutaml/uml/top_element_attribute"

module Lutaml
  module Lml
    class Instance < Lutaml::Model::Serializable; end

    class TopElementAttribute < Uml::TopElementAttribute
      attribute :properties, TopElementAttribute, collection: true, default: -> { [] }
      attribute :value, Lutaml::Model::Type::Value
      attribute :attributes, TopElementAttribute, collection: true, default: -> { [] }
      attribute :extended, :boolean
      attribute :instances, Instance, collection: true, default: -> { [] }
    end
  end
end
