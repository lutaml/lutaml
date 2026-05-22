# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaDiagram < SpaBase
          attribute :id, :string
          attribute :xmi_id, :string
          attribute :name, :string
          attribute :type, :string
          attribute :package, :string
          attribute :object_count, :integer, default: 0
          attribute :link_count, :integer, default: 0
          attribute :svg, :string

          json do
            map "id", to: :id
            map "xmiId", to: :xmi_id
            map "name", to: :name
            map "type", to: :type
            map "package", to: :package
            map "objectCount", to: :object_count, render_default: true
            map "linkCount", to: :link_count, render_default: true
            map "svg", to: :svg
          end
        end
      end
    end
  end
end
