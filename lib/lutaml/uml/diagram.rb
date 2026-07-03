# frozen_string_literal: true

module Lutaml
  module Uml
    class Diagram < TopElement
      skip_reference_registration

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
