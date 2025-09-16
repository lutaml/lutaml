# frozen_string_literal: true

require 'lutaml/lml/top_element_attribute'

module Lutaml
  module Lml
    class InstancesExport < Lutaml::Model::Serializable
      attribute :format_type, :string
      attribute :attributes, TopElementAttribute, collection: true, default: []
    end
  end
end