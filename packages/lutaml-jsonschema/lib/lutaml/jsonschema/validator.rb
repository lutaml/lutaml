# frozen_string_literal: true

require "json_schemer"

module Lutaml
  module Jsonschema
    # Meta-schema validation with fully vendored schemas: every dialect
    # and vocabulary document resolves from meta_schemas/, so validation
    # never touches the network (standards work is often air-gapped).
    class Validator
      META_DIR = File.expand_path("meta_schemas", __dir__)

      # rubocop:disable Naming/VariableNumber -- keys mirror dialect names
      ROOTS = {
        draft4: "https://json-schema.org/draft-04/schema",
        draft6: "https://json-schema.org/draft-06/schema",
        draft7: "https://json-schema.org/draft-07/schema",
        draft2019_09: "https://json-schema.org/draft/2019-09/schema",
        draft2020_12: "https://json-schema.org/draft/2020-12/schema",
      }.freeze
      # rubocop:enable Naming/VariableNumber

      ValidationError = Struct.new(:pointer, :keyword, :message,
                                   keyword_init: true) do
        def to_h
          { pointer: pointer, keyword: keyword, message: message }
        end
      end

      class UnresolvableReference < Error; end

      class << self
        def supported?(dialect)
          ROOTS.key?(dialect)
        end

        # Returns an array of ValidationError for invalid documents, []
        # for valid ones, or nil when the dialect has no bundled
        # meta-schema.
        def validate(document, dialect)
          return nil unless supported?(dialect)

          schemer(dialect).validate(document).map do |err|
            ValidationError.new(
              pointer: err["data_pointer"],
              keyword: err["type"],
              message: err["error"],
            )
          end
        end

        # A JSONSchemer instance for the dialect's root meta-schema,
        # resolving every $ref from the vendored corpus.
        def schemer(dialect)
          @schemers ||= {}
          @schemers[dialect] ||= begin
            root_uri = normalize(ROOTS.fetch(dialect))
            document = document_uri_index.fetch(root_uri) do
              raise UnresolvableReference, "Missing bundled meta-schema: #{root_uri}"
            end
            JSONSchemer.schema(document, ref_resolver: resolver)
          end
        end

        # Normalized $id/id -> parsed vendored document, for every
        # meta-schema file (roots and vocabulary documents alike).
        def document_uri_index
          @document_uri_index ||= Dir[File.join(META_DIR, "**", "*.json")]
            .each_with_object({}) do |path, index|
              doc = Yeptris::JSON.load(File.read(path))
              id = doc["$id"] || doc["id"] || path.delete_prefix("#{META_DIR}/")
              index[normalize(id)] = doc
            end
        end

        def resolver
          lambda do |uri|
            document_uri_index.fetch(normalize(uri.to_s)) do
              raise UnresolvableReference,
                    "Unresolvable meta-schema reference: #{uri}"
            end
          end
        end

        def normalize(uri)
          uri.to_s.delete_suffix("#").sub(%r{\Ahttp://}, "https://")
        end
      end
    end
  end
end
