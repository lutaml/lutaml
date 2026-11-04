# frozen_string_literal: true

module Expressir
  module Express
    # Edition awareness for ISO 10303-11. The grammar accepts the union
    # of both editions' text syntax; edition gating is reported by the
    # Checker so a 1994 consumer sees exactly which declarations use
    # 2004-only constructs, and a 2004 consumer sees the edition-1
    # syntax the 2004 edition deprecates (Annex K).
    module Dialect
      EDITION_1994 = :"10303-11:1994"
      EDITION_2004 = :"10303-11:2004"
      DIALECTS = [EDITION_1994, EDITION_2004].freeze
      DEFAULT = EDITION_2004

      # The audited change list lives in
      # spec/fixtures/dialects/iso-10303-11-2004-changes.yaml; every
      # construct there maps to a note id below.
      NOTE_IDS = %i[
        check_dialect_2004_only
        check_dialect_deprecated
        check_dialect_mixed
      ].freeze

      module_function

      def normalize(value)
        return DEFAULT if value.nil?

        candidate = value.to_s
        dialect = DIALECTS.find do |entry|
          entry.to_s == candidate || entry.to_s.end_with?(":#{candidate}")
        end
        return dialect if dialect

        raise Expressir::InvalidOptionError.new(
          "dialect",
          value,
          valid_options: DIALECTS.map(&:to_s),
        )
      end
    end
  end
end
