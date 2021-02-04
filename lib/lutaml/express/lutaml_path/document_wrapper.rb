require "lutaml/lutaml_path/document_wrapper"
require "expressir/express_exp/formatter"

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        SCHEMA_ATTRIBUTES = %w[
          id
          constants
          declarations
          entities
          functions
          interfaces
          procedures
          remarks
          rules
          subtype_constraints
          types
          version
          head_source
          type
        ].freeze
        SOURCE_CODE_ATTRIBUTE_NAME = "sourcecode".freeze

        protected

        def serialize_document(repository)
          repository.schemas.each_with_object({}) do |schema, res|
            res["schemas"] ||= []
            serialized_schema = SCHEMA_ATTRIBUTES
              .each_with_object({}) do |name, nested_res|
              attr_value = schema.send(name)
              nested_res[name] = serialize_value(attr_value)
              if name == "entities"
                nested_res[name] = merge_source_code_attr(nested_res[name],
                                                          attr_value)
              end
            end
            res[schema.id] = serialized_schema
            serialized_schema = serialized_schema
              .merge(SOURCE_CODE_ATTRIBUTE_NAME =>
                                          entity_source_code(schema))
            res["schemas"].push(serialized_schema)
          end
        end

        def merge_source_code_attr(serialized_entries, entities)
          serialized_entries.map do |serialized|
            entity = entities.detect { |n| n.id == serialized["id"] }
            serialized.merge(SOURCE_CODE_ATTRIBUTE_NAME => entity_source_code(entity))
          end
        end

        def entity_source_code(entity)
          Expressir::ExpressExp::Formatter.format(entity)
        end
      end
    end
  end
end
