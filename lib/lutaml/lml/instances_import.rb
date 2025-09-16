# frozen_string_literal: true

require 'lutaml/lml/top_element_attribute'

module Lutaml
  module Lml
    class InstancesImport < Lutaml::Model::Serializable
      attribute :format_type, :string
      attribute :file, :string
      attribute :attributes, TopElementAttribute
    end
  end
end