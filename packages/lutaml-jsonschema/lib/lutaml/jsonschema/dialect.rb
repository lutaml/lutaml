# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # JSON Schema dialect detection from the `$schema` URI.
    #
    # Rendering and (future) validation must branch on the dialect where
    # keyword semantics differ — classic case: exclusiveMinimum/
    # exclusiveMaximum are boolean modifiers in draft-04 and standalone
    # numbers from draft-06 on.
    module Dialect
      # rubocop:disable Naming/VariableNumber -- the symbols mirror the
      # published dialect names ("2019-09", "2020-12")
      DRAFT4 = :draft4
      DRAFT6 = :draft6
      DRAFT7 = :draft7
      DRAFT2019_09 = :draft2019_09
      DRAFT2020_12 = :draft2020_12
      UNSPECIFIED = :unspecified
      # rubocop:enable Naming/VariableNumber

      URIS = {
        "https://json-schema.org/draft-04/schema" => DRAFT4,
        # the draft-04/07 hyper-schema metaschemas declare the same core
        # dialect; interagent-era API schemas reference them
        "https://json-schema.org/draft-04/hyper-schema" => DRAFT4,
        "https://json-schema.org/draft-06/schema" => DRAFT6,
        "https://json-schema.org/draft-07/schema" => DRAFT7,
        "https://json-schema.org/draft-07/hyper-schema" => DRAFT7,
        "https://json-schema.org/draft/2019-09/schema" => DRAFT2019_09,
        "https://json-schema.org/draft/2020-12/schema" => DRAFT2020_12,
      }.freeze

      module_function

      def detect(uri)
        return UNSPECIFIED if uri.nil? || uri.empty?

        URIS[normalize(uri)] || UNSPECIFIED
      end

      def normalize(uri)
        uri.to_s.delete_suffix("#").sub(%r{\Ahttp://}, "https://")
      end

      # draft-04 uses `exclusiveMinimum: true` alongside `minimum`;
      # from draft-06 on the keyword carries the bound itself.
      def numeric_exclusive_bounds?(dialect)
        dialect != DRAFT4
      end

      # draft-04 ignores keywords beside `$ref`; 2019-09 and later apply
      # them. The renderer annotates the difference rather than lying.
      def ignore_ref_siblings?(dialect)
        dialect == DRAFT4
      end

      # draft-04/06/07 validate `format`; from 2019-09 on it is an
      # annotation unless the vocabulary opts in.
      def format_asserts?(dialect)
        [DRAFT4, DRAFT6, DRAFT7].include?(dialect)
      end
    end
  end
end
