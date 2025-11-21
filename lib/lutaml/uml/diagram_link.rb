# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Uml
    # Represents visual routing of a connector on a diagram
    class DiagramLink < Lutaml::Model::Serializable
      attribute :connector_id, :string
      attribute :connector_xmi_id, :string
      attribute :geometry, :string
      attribute :style, :string
      attribute :hidden, :boolean, default: -> { false }
      attribute :path, :string

      yaml do
        map "connector_id", to: :connector_id
        map "connector_xmi_id", to: :connector_xmi_id
        map "geometry", to: :geometry
        map "style", to: :style
        map "hidden", to: :hidden
        map "path", to: :path
      end
    end
  end
end