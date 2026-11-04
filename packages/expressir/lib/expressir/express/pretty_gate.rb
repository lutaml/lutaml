# frozen_string_literal: true

module Expressir
  module Express
    # Pretty round-trip gate (parity-ee stage 08 / eeng qualify.sh
    # self-check): parse → format → re-parse and compare a structural
    # fingerprint of the model. Byte identity is deliberately not
    # required — remark placement and whitespace drift are tolerated;
    # declaration inventory and interface shape must match.
    class PrettyGate
      Result = Struct.new(:path, :ok, :before, :after, :error, keyword_init: true)

      def self.fingerprint(schema)
        {
          id: schema.id&.safe_downcase,
          interfaces: Array(schema.interfaces).map do |i|
            {
              kind: i.kind,
              schema: (i.schema.is_a?(String) ? i.schema : i.schema&.id)&.safe_downcase,
              items: Array(i.items).map do |entry|
                ref = entry.ref.is_a?(String) ? entry.ref : entry.ref&.id
                [entry.id&.safe_downcase, ref&.safe_downcase]
              end.sort,
            }
          end,
          constants: ids_of(schema.constants),
          types: ids_of(schema.types),
          entities: ids_of(schema.entities),
          subtype_constraints: ids_of(schema.subtype_constraints),
          functions: ids_of(schema.functions),
          procedures: ids_of(schema.procedures),
          rules: ids_of(schema.rules),
          entity_attrs: Array(schema.entities).to_h do |e|
            [e.id.safe_downcase, Array(e.attributes).filter_map { |a| a.id&.safe_downcase }.sort]
          end,
        }
      end

      def self.ids_of(coll)
        Array(coll).filter_map { |d| d.id&.safe_downcase }.sort
      end

      def self.check_file(path)
        source = File.read(path)
        original = Parser.from_exp(source, skip_references: true)
        formatted = Formatter.format(original)
        roundtrip = Parser.from_exp(formatted, skip_references: true)

        before = original.schemas.map { |s| fingerprint(s) }
        after = roundtrip.schemas.map { |s| fingerprint(s) }
        Result.new(path: path, ok: before == after, before: before, after: after)
      rescue StandardError => e
        Result.new(path: path, ok: false, error: e)
      end

      def self.check_files(paths)
        paths.map { |p| check_file(p) }
      end
    end
  end
end
