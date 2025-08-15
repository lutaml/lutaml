# frozen_string_literal: true

module Lutaml
  module Uml
    class TopElement < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :xmi_id, :string
      attribute :xmi_uuid, :string
      attribute :namespace, NameSpace
      attribute :keyword, :string
      attribute :stereotype, :string, collection: true, default: -> { [] }
      attribute :href, :string
      attribute :visibility, :string, default: "public"
      attribute :comments, :string, collection: true

      attribute :definition, :string
      attribute :full_name, :string

      yaml do
        map "name", to: :name
        map "xmi_id", to: :xmi_id
        map "xmi_uuid", to: :xmi_uuid
        map "namespace", to: :namespace
        map "keyword", to: :keyword
        map "stereotype", to: :stereotype
        map "href", to: :href
        map "visibility", to: :visibility
        map "comments", to: :comments

        map "definition", to: :definition, with: {
          to: :definition_to_yaml, from: :definition_from_yaml
        }
        map "full_name", with: {
          to: :full_name_to_yaml, from: :full_name_from_yaml
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

      def full_name_to_yaml(model, doc) # rubocop:disable Metrics/MethodLength
        return model.full_name if model.full_name

        # If full_name is not set, calculate it
        full_name = nil
        if model.name == nil
          return full_name
        end

        full_name = model.name
        next_namespace = model.namespace

        while !next_namespace.nil?
          full_name = if next_namespace.name.nil?
                        "::#{full_name}"
                      else
                        "#{next_namespace.name}::#{full_name}"
                      end
          next_namespace = next_namespace.namespace
        end

        doc["full_name"] = full_name
      end

      def full_name_from_yaml(model, value)
        model.full_name = value
      end
    end
  end
end
