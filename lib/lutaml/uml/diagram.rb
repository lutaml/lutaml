# frozen_string_literal: true

module Lutaml
  module Uml
    class Diagram < TopElement
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

      attribute :package_id, :string
      attribute :package_name, :string
      attribute :diagram_type, :string
      attribute :diagram_objects, DiagramObject, collection: true,
                                                 default: -> { [] }
      attribute :diagram_links, DiagramLink, collection: true,
                                             default: -> { [] }

      yaml do
        map "package_id", to: :package_id
        map "package_name", to: :package_name
        map "diagram_type", to: :diagram_type
        map "diagram_objects", to: :diagram_objects
        map "diagram_links", to: :diagram_links
      end
    end
  end
end
