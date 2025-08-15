# frozen_string_literal: true

module Lutaml
  module Uml
    class Value < Lutaml::Model::Serializable
      attribute :definition, :string
      attribute :name, :string
      attribute :id, :string
      attribute :type, :string

      yaml do
        map "name", to: :name
        map "id", to: :id
        map "type", to: :type

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
