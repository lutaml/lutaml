# frozen_string_literal: true

require "json"

module Lutaml
  module Jsonschema
    module Exports
      # Renders a SchemaSet as an OpenAPI 3.1 document.
      #
      # JSON Schema 2020-12 is the OpenAPI 3.1 schema dialect, so 2020-12
      # schemas are emitted verbatim under components.schemas. Older
      # dialects (draft-04/06/07) are emitted as-is too, but note that
      # their keyword semantics can differ from OAS 3.1's dialect.
      class Openapi
        def initialize(schema_set, title: nil, version: "1.0.0")
          @schema_set = schema_set
          @title = title
          @version = version
        end

        def render
          JSON.pretty_generate(document)
        end

        def document
          {
            "openapi" => "3.1.0",
            "info" => { "title" => title, "version" => @version },
            "components" => { "schemas" => schemas },
          }
        end

        private

        def schemas
          @schema_set.schemas.to_h do |name, schema|
            [name, Yeptris::JSON.load(schema.to_json)]
          end
        end

        def title
          @title || @schema_set.schemas.values.first&.title ||
            "Schema Documentation"
        end
      end
    end
  end
end
