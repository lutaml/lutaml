require 'lutaml/lutaml_path/document_wrapper'

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
          rules
          subtype_constraints
          types
          version
        ].freeze

        protected

        def serialize_document(repository)
          repository.schemas.each_with_object({}) do |schema, res|
            res['schemas'] ||= []
            serialized_schema = SCHEMA_ATTRIBUTES.each_with_object({}) do |name, nested_res|
              attr_value = schema.send(name)
              nested_res[name] = serialize_value(attr_value)
            end
            res[schema.id] = serialized_schema
            res['schemas'].push(serialized_schema)
          end
        end
      end
    end
  end
end