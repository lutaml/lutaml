# frozen_string_literal: true

module Lutaml
  module Uml
    class Package < TopElement
      skip_reference_registration

      attribute :contents, :string, collection: true, default: -> { [] }
      attribute :classes, Class, collection: true, default: -> { [] }
      attribute :enums, Enum, collection: true, default: -> { [] }
      attribute :data_types, DataType, collection: true, default: -> { [] }
      attribute :instances, Instance, collection: true, default: -> { [] }
      attribute :packages, Package, collection: true, default: -> { [] }
      attribute :diagrams, Diagram, collection: true, default: -> { [] }

      yaml do
        map "contents", to: :contents
        map "classes", to: :classes
        map "enums", to: :enums
        map "data_types", to: :data_types
        map "instances", to: :instances
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
