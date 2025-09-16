# frozen_string_literal: true

require 'lutaml/lml/top_element_attribute'

module Lutaml
  module Lml
    class Instance < Lutaml::Model::Serializable
      attribute :type, :string
      attribute :attributes, TopElementAttribute, collection: true
      attribute :instance, Instance
      attribute :template, TopElementAttribute, collection: true
      attribute :parent, :string
    end
  end
end