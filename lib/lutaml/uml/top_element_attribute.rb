# frozen_string_literal: true

module Lutaml
  module Uml
    class TopElementAttribute < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :visibility, :string, default: "public"
      attribute :type, :string
      attribute :id, :string
      attribute :xmi_id, :string
      attribute :contain, :string
      attribute :static, :string
      attribute :cardinality, Cardinality
      attribute :keyword, :string
      attribute :is_derived, :boolean, default: false

      attribute :definition, :string

      yaml do
        map "name", to: :name
        map "visibility", to: :visibility
        map "type", to: :type
        map "id", to: :id
        map "xmi_id", to: :xmi_id
        map "contain", to: :contain
        map "static", to: :static
        map "cardinality", to: :cardinality
        map "keyword", to: :keyword
        map "is_derived", to: :is_derived

        map "definition", to: :definition, with: {
          to: :definition_to_yaml, from: :definition_from_yaml
        }
      end

      def definition_to_yaml(model, doc)
        doc["definition"] = model.definition if model.definition
      end

      def definition_from_yaml(model, value)
        model.definition = value.to_s
          .gsub(/\\}/, "}")
          .gsub(/\\{/, "{")
          .split("\n")
          .map(&:strip)
          .join("\n")
      end
    end
  end
end
