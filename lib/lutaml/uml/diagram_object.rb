# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Uml
    # Represents visual placement of an element on a diagram
    class DiagramObject < Lutaml::Model::Serializable
      attribute :diagram_object_id, :string
      attribute :object_xmi_id, :string
      attribute :left, :integer
      attribute :top, :integer
      attribute :right, :integer
      attribute :bottom, :integer
      attribute :sequence, :integer
      attribute :style, :string

      yaml do
        map "object_id", to: :diagram_object_id
        map "object_xmi_id", to: :object_xmi_id
        map "left", to: :left
        map "top", to: :top
        map "right", to: :right
        map "bottom", to: :bottom
        map "sequence", to: :sequence
        map "style", to: :style
      end
    end
  end
end