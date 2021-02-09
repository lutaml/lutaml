require "lutaml/lutaml_path/document_wrapper"
require "expressir/express_exp/formatter"

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        SOURCE_CODE_ATTRIBUTE_NAME = "sourcecode".freeze

        protected

        def serialize_document(repository)
          repository.schemas.each_with_object({}) do |schema, res|
            res["schemas"] ||= []
            res[schema.id] = serialize_value(schema).merge(SOURCE_CODE_ATTRIBUTE_NAME => entity_source_code(schema))
            res["schemas"].push(res[schema.id])
          end
        end

        def serialize_value(object)
          object.instance_variables.each_with_object({}) do |var, res|
            variable = object.instance_variable_get(var)
            if variable.respond_to?(:to_hash)
              res[var.to_s.gsub("@", "")] = variable.to_hash.merge(SOURCE_CODE_ATTRIBUTE_NAME => entity_source_code(variable))
            elsif variable.is_a?(Array)
              res[var.to_s.gsub("@", "")] = variable.map do |entity|
                if entity.respond_to?(:to_hash)
                  entity.to_hash.merge(SOURCE_CODE_ATTRIBUTE_NAME => entity_source_code(entity))
                else
                  entity
                end
              end
            else
              res[var.to_s.gsub("@", "")] = variable
            end
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
