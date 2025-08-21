# frozen_string_literal: true

module Lutaml
  module Uml
    class Document < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :title, :string
      attribute :caption, :string
      attribute :groups, Group, collection: true
      attribute :fidelity, Fidelity
      attribute :fontname, :string
      attribute :comments, :string, collection: true

      attribute :classes, Class, collection: true, default: -> { [] }
      attribute :data_types, DataType, collection: true, default: -> { [] }
      attribute :enums, Enum, collection: true, default: -> { [] }
      attribute :packages, Package, collection: true, default: -> { [] }
      attribute :primitives, PrimitiveType, collection: true, default: -> { [] }
      attribute :associations, Association, collection: true, default: -> { [] }

      yaml do
        map "name", to: :name
        map "title", to: :title
        map "caption", to: :caption
        map "groups", to: :groups
        map "fidelity", to: :fidelity
        map "fontname", to: :fontname
        map "comments", to: :comments

        map "classes", to: :classes
        map "data_types", to: :data_types
        map "enums", to: :enums
        map "packages", to: :packages
        map "primitives", to: :primitives

        map "associations", to: :associations, with: {
          to: :associations_to_yaml, from: :associations_from_yaml
        }
      end

      def associations_to_yaml(model, doc)
        associations = model.associations.map(&:to_hash)
        doc["associations"] = associations unless associations.empty?
      end

      def associations_from_yaml(model, values)
        associations = values.map do |value|
          value["owner_end"] = model.name if value["owner_end"].nil?
          Association.from_yaml(value.to_yaml)
        end

        model.associations = associations
      end
    end
  end
end
