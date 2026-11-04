# frozen_string_literal: true

module Expressir
  module Eval
    # The built-in conformance matrix (TODO.compat/07): the ISO
    # 10303-11 standard functions (clause 15), each row cited per
    # clause with its coverage status in Expressir::Eval. The
    # generated matrix (docs/_guides/compat/eval-builtin-matrix.adoc)
    # is produced by this table; the spec mutates every implemented
    # function per clause examples.
    module BuiltinMatrix
      Row = Struct.new(:name, :clause, :status, :note, keyword_init: true)

      IMPLEMENTED = "implemented"
      DIVERGENT = "divergent"

      ROWS = [
        Row.new(name: "ABS", clause: "15.1", status: IMPLEMENTED),
        Row.new(name: "ACOS", clause: "15.2", status: IMPLEMENTED),
        Row.new(name: "ASIN", clause: "15.3", status: IMPLEMENTED),
        Row.new(name: "ATAN", clause: "15.4", status: IMPLEMENTED),
        Row.new(name: "ATAN2", clause: "15.4", status: IMPLEMENTED,
                note: "two-argument arctangent"),
        Row.new(name: "BLENGTH", clause: "15.5", status: IMPLEMENTED),
        Row.new(name: "BOUNDS", clause: "15.6", status: IMPLEMENTED,
                note: "evaluated aggregates: [1, size]"),
        Row.new(name: "COS", clause: "15.7", status: IMPLEMENTED),
        Row.new(name: "EXISTS", clause: "15.8", status: IMPLEMENTED),
        Row.new(name: "EXP", clause: "15.9", status: IMPLEMENTED),
        Row.new(name: "FORMAT", clause: "15.10", status: DIVERGENT,
                note: "not evaluated (D-06)"),
        Row.new(name: "HIBOUND", clause: "15.11", status: IMPLEMENTED,
                note: "evaluated aggregates: size"),
        Row.new(name: "HIINDEX", clause: "15.12", status: IMPLEMENTED,
                note: "evaluated aggregates: size"),
        Row.new(name: "LENGTH", clause: "15.13", status: IMPLEMENTED),
        Row.new(name: "LOBOUND", clause: "15.14", status: IMPLEMENTED,
                note: "evaluated aggregates: 1"),
        Row.new(name: "LOINDEX", clause: "15.15", status: IMPLEMENTED,
                note: "evaluated aggregates: 1"),
        Row.new(name: "LOG", clause: "15.16", status: IMPLEMENTED),
        Row.new(name: "LOG2", clause: "15.16", status: IMPLEMENTED),
        Row.new(name: "LOG10", clause: "15.16", status: IMPLEMENTED),
        Row.new(name: "NVL", clause: "15.19", status: IMPLEMENTED),
        Row.new(name: "ODD", clause: "15.20", status: IMPLEMENTED),
        Row.new(name: "ROLESOF", clause: "15.21", status: IMPLEMENTED,
                note: "degenerate: no role metadata — empty set (D-06)"),
        Row.new(name: "SIN", clause: "15.22", status: IMPLEMENTED),
        Row.new(name: "SIZEOF", clause: "15.23", status: IMPLEMENTED),
        Row.new(name: "SQRT", clause: "15.24", status: IMPLEMENTED),
        Row.new(name: "TAN", clause: "15.25", status: IMPLEMENTED),
        Row.new(name: "TYPEOF", clause: "15.26", status: IMPLEMENTED),
        Row.new(name: "USEDIN", clause: "15.27", status: IMPLEMENTED),
        Row.new(name: "VALUE", clause: "15.28", status: IMPLEMENTED),
        Row.new(name: "VALUE_IN", clause: "15.29", status: IMPLEMENTED),
        Row.new(name: "VALUE_UA", clause: "15.29", status: DIVERGENT,
                note: "not evaluated (D-06)"),
      ].freeze

      module_function

      def to_adoc
        lines = [
          "= Eval built-in function matrix",
          "",
          "Coverage of the ISO 10303-11 clause 15 standard functions in",
          "`Expressir::Eval`, generated from `Expressir::Eval::BuiltinMatrix`.",
          "Divergent rows are registered in",
          "xref:interchange[the interchange and divergences page].",
          "",
          "[cols=\"1,1,1,2\"]",
          "|===",
          "| Function | Clause | Status | Note",
        ]
        ROWS.each do |row|
          lines << "| `#{row.name}` | #{row.clause} | #{row.status} | #{row.note} |"
        end
        lines << "|==="
        lines.join("\n") << "\n"
      end
    end
  end
end
