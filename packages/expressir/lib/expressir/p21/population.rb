# frozen_string_literal: true

module Expressir
  module P21
    # A parsed ISO 10303-21 exchange structure (TODO.eengine/06).
    # `header`   — Hash: keyword => parameters (Array of values).
    # `instances`— Hash: "#id" => Record.
    #
    # Values: String (string literal), Integer (reference id, keyed as
    # "#id" in instances), Expressir::P21::Enumeration,
    # Expressir::P21::Binary, Expressir::P21::TypedValue,
    # Expressir::P21::ComplexRecord, :unset, :derived, or nested
    # Arrays for lists.
    class Population
      attr_reader :header, :instances, :sections, :anchors, :references

      def initialize(header: {}, instances: {}, sections: [], anchors: {},
                     references: {})
        @header = header
        @instances = instances
        @sections = sections
        @anchors = anchors
        @references = references
      end
    end

    # A data-section instance: `#12 = KEYWORD(param, ...) ;`
    Record = Struct.new(:keyword, :params)

    # `#21 = (A(...) B(...))` — complex entity instance.
    ComplexRecord = Struct.new(:records)

    TypedValue = Struct.new(:keyword, :value)

    Enumeration = Struct.new(:name)

    Binary = Struct.new(:hex)
  end
end
