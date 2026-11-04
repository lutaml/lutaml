# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # Semantic diff between two schema documents (TODO.sota/07).
    #
    # Classifications describe consumer impact:
    # - breaking: existing instances or generated code may stop working
    #   (property/type/definition removed, requirement added, constraints
    #   tightened, enum narrowed)
    # - additive: new capability without breaking existing instances
    #   (property/enum value added, requirement removed, constraints relaxed)
    # - cosmetic: documentation-only changes
    class Diff
      BREAKING = :breaking
      ADDITIVE = :additive
      COSMETIC = :cosmetic

      Change = Struct.new(:pointer, :kind, :classification, :detail,
                          keyword_init: true) do
        def to_h
          { pointer: pointer, kind: kind, classification: classification,
            detail: detail }
        end
      end

      def self.between(old_schema, new_schema)
        new(old_schema, new_schema).changes
      end

      def initialize(old_schema, new_schema)
        @old = old_schema
        @new = new_schema
      end

      def changes
        @changes ||= begin
          @changes = []
          compare_schemas(@old, @new, "")
          @changes
        end
      end

      def breaking?
        changes.any? { |change| change.classification == BREAKING }
      end

      private

      def compare_schemas(old, new, pointer)
        unless old.is_a?(Schema) && new.is_a?(Schema)
          compare_boolean_schemas(old, new, pointer)
          return
        end

        compare_keywords(old, new, pointer)
        compare_children(old, new, pointer)
      end

      # `true` accepts everything and `false` accepts nothing, so a schema
      # replaced by a boolean (or vice versa) changes what consumers must
      # accept even though there are no keywords to compare.
      def compare_boolean_schemas(old, new, pointer)
        return if old.equal?(new)

        if new == true
          add(pointer, :changed, ADDITIVE, "accepts anything")
        elsif new == false
          add(pointer, :changed, BREAKING, "accepts nothing")
        elsif old == false
          add(pointer, :changed, ADDITIVE, "schema was unsatisfiable")
        elsif old == true
          add(pointer, :changed, BREAKING, "schema accepted anything")
        end
      end

      def compare_keywords(old, new, pointer)
        compare_meta(old, new, pointer)
        compare_type(old, new, pointer)
        compare_ref(old, new, pointer)
        compare_required(old, new, pointer)
        compare_enum(old, new, pointer)
        compare_min_bounds(old, new, pointer)
        compare_max_bounds(old, new, pointer)
        compare_scalar_constraints(old, new, pointer)
      end

      # A retargeted $ref changes what consumers must produce/accept even
      # when the surrounding schema looks unchanged.
      def compare_ref(old, new, pointer)
        return if old.dollar_ref == new.dollar_ref

        add(join(pointer, "$ref"), :changed, BREAKING,
            "#{old.dollar_ref.inspect} -> #{new.dollar_ref.inspect}")
      end

      def compare_children(old, new, pointer)
        compare_entries(old.property_entries, new.property_entries, pointer,
                        "properties", "property")
        compare_entries(old.definition_entries, new.definition_entries,
                        pointer, "definitions", "definition")
      end

      def compare_meta(old, new, pointer)
        if old.description != new.description
          add(join(pointer, "description"), :changed, COSMETIC,
              "description changed")
        end
        if old.title != new.title
          add(join(pointer, "title"), :changed, COSMETIC, "title changed")
        end
        return if old.deprecated == new.deprecated

        add(join(pointer, "deprecated"), :changed, COSMETIC,
            "deprecated #{old.deprecated ? 'removed' : 'added'}")
      end

      def compare_type(old, new, pointer)
        return if old.type == new.type

        add(join(pointer, "type"), :changed, BREAKING,
            "#{old.type.inspect} -> #{new.type.inspect}")
      end

      def compare_required(old, new, pointer)
        (new.required - old.required).each do |name|
          add(join(pointer, "required"), :added, BREAKING,
              "property #{name.inspect} became required")
        end
        (old.required - new.required).each do |name|
          add(join(pointer, "required"), :removed, ADDITIVE,
              "property #{name.inspect} is no longer required")
        end
      end

      def compare_entries(old_entries, new_entries, pointer, segment, noun)
        old_map = entries_by_name(old_entries)
        new_map = entries_by_name(new_entries)

        report_additions(old_map, new_map, pointer, segment, noun)
        report_removals(old_map, new_map, pointer, segment, noun)
        compare_common(old_map, new_map, pointer, segment)
      end

      def report_additions(old_map, new_map, pointer, segment, noun)
        (new_map.keys - old_map.keys).each do |name|
          add(join(pointer, segment, name), :added, ADDITIVE, "#{noun} added")
        end
      end

      def report_removals(old_map, new_map, pointer, segment, noun)
        (old_map.keys - new_map.keys).each do |name|
          add(join(pointer, segment, name), :removed, BREAKING,
              "#{noun} removed")
        end
      end

      def compare_common(old_map, new_map, pointer, segment)
        (old_map.keys & new_map.keys).each do |name|
          compare_schemas(old_map[name], new_map[name],
                          join(pointer, segment, name))
        end
      end

      def compare_enum(old, new, pointer)
        report_enum(old.enum.to_a - new.enum.to_a, pointer, :removed,
                    BREAKING, "removed")
        report_enum(new.enum.to_a - old.enum.to_a, pointer, :added,
                    ADDITIVE, "added")
      end

      def report_enum(values, pointer, kind, classification, verb)
        values.each do |value|
          add(join(pointer, "enum"), kind, classification,
              "enum value #{value.inspect} #{verb}")
        end
      end

      # Tighter bounds are breaking (instances that validated stop
      # validating); looser bounds are additive.
      def compare_min_bounds(old, new, pointer)
        compare_bound(old.minimum, new.minimum, "minimum", pointer, :min)
        compare_bound(old.min_length, new.min_length, "minLength", pointer,
                      :min)
        compare_bound(old.min_items, new.min_items, "minItems", pointer, :min)
        compare_bound(old.min_properties, new.min_properties, "minProperties",
                      pointer, :min)
      end

      def compare_max_bounds(old, new, pointer)
        compare_bound(old.maximum, new.maximum, "maximum", pointer, :max)
        compare_bound(old.max_length, new.max_length, "maxLength", pointer,
                      :max)
        compare_bound(old.max_items, new.max_items, "maxItems", pointer, :max)
        compare_bound(old.max_properties, new.max_properties, "maxProperties",
                      pointer, :max)
      end

      def compare_bound(old_value, new_value, keyword, pointer, direction)
        return if old_value == new_value

        classification =
          if new_value.nil?
            ADDITIVE
          elsif old_value.nil?
            BREAKING
          else
            loosened = direction == :min ? new_value < old_value : new_value > old_value
            loosened ? ADDITIVE : BREAKING
          end
        add(join(pointer, keyword), :changed, classification,
            "#{keyword} #{old_value.inspect} -> #{new_value.inspect}")
      end

      def compare_scalar_constraints(old, new, pointer)
        compare_multiple_of(old, new, pointer)
        compare_pattern(old, new, pointer)
        compare_unique(old, new, pointer)
        compare_closedness(old, new, pointer)
      end

      def compare_multiple_of(old, new, pointer)
        return if old.multiple_of == new.multiple_of

        add(join(pointer, "multipleOf"), :changed, BREAKING,
            "multipleOf #{old.multiple_of.inspect} -> #{new.multiple_of.inspect}")
      end

      def compare_pattern(old, new, pointer)
        return if old.pattern == new.pattern

        add(join(pointer, "pattern"), :changed, BREAKING, "pattern changed")
      end

      def compare_unique(old, new, pointer)
        return if old.unique_items == new.unique_items

        if new.unique_items == false
          add(join(pointer, "uniqueItems"), :changed, ADDITIVE,
              "uniqueItems relaxed")
        else
          add(join(pointer, "uniqueItems"), :changed, BREAKING,
              "uniqueItems enforced")
        end
      end

      def compare_closedness(old, new, pointer)
        return if old.additional_properties == new.additional_properties

        if old.additional_properties == false
          add(join(pointer, "additionalProperties"), :changed, ADDITIVE,
              "additionalProperties relaxed")
        else
          add(join(pointer, "additionalProperties"), :changed, BREAKING,
              "additionalProperties restricted")
        end
      end

      def entries_by_name(entries)
        entries.to_h { |entry| [entry.name, entry.schema_value] }
      end

      def join(*parts)
        segments = parts.map(&:to_s).reject(&:empty?)
        pointer = segments.join("/")
        pointer.start_with?("/") ? pointer : "/#{pointer}"
      end

      def add(pointer, kind, classification, detail)
        @changes << Change.new(pointer: pointer, kind: kind,
                               classification: classification, detail: detail)
      end
    end
  end
end
