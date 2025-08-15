# frozen_string_literal: true

require "lutaml/uml/class"
require "lutaml/uml/enum"
require "lutaml/uml/data_type"
require "lutaml/uml/diagram"

module Lutaml
  module Uml
    class Package < TopElement
      attribute :contents, :string, collection: true, default: -> { [] }
      attribute :classes, Class, collection: true, default: -> { [] }
      attribute :enums, Enum, collection: true, default: -> { [] }
      attribute :data_types, DataType, collection: true, default: -> { [] }
      attribute :packages, Package, collection: true, default: -> { [] }
      attribute :diagrams, Diagram, collection: true, default: -> { [] }

      yaml do
        map "contents", to: :contents
        map "classes", to: :classes
        map "enums", to: :enums
        map "data_types", to: :data_types
        map "packages", to: :packages
        map "diagrams", to: :diagrams
      end

      def children_packages
        packages.map do |pkg|
          [pkg, pkg.packages, pkg.packages.map(&:children_packages)]
        end.flatten.uniq
      end
    end
  end
end
