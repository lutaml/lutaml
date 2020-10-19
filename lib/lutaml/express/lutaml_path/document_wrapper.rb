require 'lutaml/lutaml_path/document_wrapper'

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        SCHEMA_ATTRIBUTES = %i[
          id
          constants
          declarations
          entities
          functions
          interfaces
          procedures
          rules
          subtype_constraints
          types
          version
        ].freeze

        protected

        def serialize_document(repository)
          repository.schemas.each_with_object({}) do |schema, res|
            res[schema.id] = SCHEMA_ATTRIBUTES.each_with_object({}) do |name, nested_res|
              attr_value = schema.send(name)
              if name == :entities
                serizlie_entities(attr_value, nested_res)
              else
                nested_res[name] = serialize_value(attr_value)
              end
            end
          end
        end

        private

        def serizlie_entities(attr_value, nested_res)
          return if attr_value.nil? || attr_value.empty?

          attr_value.each do |entity|
            nested_res[entity.id] = serialize_to_hash(entity)
          end
        end

        def serialize_value(attr_value)
          if attr_value.is_a?(Array)
            return attr_value.map(&method(:serialize_to_hash))
          end

          attr_value
        end

        def serialize_to_hash(object)
          object.instance_variables.each_with_object({}) do |var, res|
            variable = object.instance_variable_get(var)
            if variable.is_a?(Array)
              res[var.to_s.gsub("@", '')] = variable.map { |n| serialize_to_hash(n) }
            else
              res[var.to_s.gsub("@", '')] = variable
            end
          end
        end
      end
    end
  end
end