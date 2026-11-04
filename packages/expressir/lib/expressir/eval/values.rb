# frozen_string_literal: true

module Expressir
  module Eval
    # EXPRESS value model (ISO 10303-11 ch.8/12): indeterminate,
    # logical, enumeration, binary and aggregates are dedicated
    # values; NUMBER-family members, strings map to Ruby natives.
    #
    # Values are frozen; aggregate operators return new values.
    module Values
      # The indeterminate value `?` (ISO 10303-11 8.6? — the
      # indeterminate sign). A singleton: comparisons and arithmetic
      # propagate it per clause instead of treating it as nil.
      INDETERMINATE = Object.new.freeze

      # EXPRESS logical values are the symbols true/false/unknown as
      # values, not Ruby booleans (ISO 10303-11 8.2).
      LOGICAL_TRUE = :true # rubocop:disable Lint/BooleanSymbol
      LOGICAL_FALSE = :false # rubocop:disable Lint/BooleanSymbol
      LOGICAL_UNKNOWN = :unknown

      Logical = Struct.new(:value, keyword_init: true) do
        # The logical values are ISO 10303-11 logical literals
        # (true/false/unknown as values), not Ruby booleans.
        def self.true_value # rubocop:disable Lint/BooleanSymbol
          new(value: LOGICAL_TRUE).freeze
        end

        def self.false_value # rubocop:disable Lint/BooleanSymbol
          new(value: LOGICAL_FALSE).freeze
        end

        def self.unknown
          new(value: LOGICAL_UNKNOWN).freeze
        end

        def to_s
          value.to_s.upcase
        end
      end

      Enumeration = Struct.new(:type, :item, keyword_init: true) do
        def to_s
          ".#{item}."
        end
      end

      Binary = Struct.new(:bits, keyword_init: true) do
        def to_s
          "%#{bits}"
        end
      end

      # A Part 21 instance: the population record plus its #id.
      Instance = Struct.new(:id, :record, keyword_init: true) do
        def to_s
          "##{id}"
        end
      end

      # kind: :list, :set, :bag or :array — union/difference/
      # intersection semantics depend on it (12.6).
      Aggregate = Struct.new(:kind, :elements, keyword_init: true) do
        def self.of(kind, elements)
          new(kind: kind, elements: elements.freeze).freeze
        end

        def size
          elements.size
        end
      end
    end
  end
end
