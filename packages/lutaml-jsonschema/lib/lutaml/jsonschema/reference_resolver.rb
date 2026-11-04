# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # Resolves `$ref` values: JSON Pointer fragments (RFC 6901),
    # anchors (`$anchor`, and the draft-04 legacy `id: "#name"` form),
    # and remote/document refs through the schema set's name map.
    class ReferenceResolver
      def initialize(schemas = {})
        @schemas = schemas
      end

      # `seen` tracks the refs followed along the current chain so that
      # cyclic references (a -> b -> a) terminate instead of recursing.
      def resolve(ref, root_schema = nil, seen = nil)
        return nil unless ref

        seen ||= {}
        return nil if seen[ref]
        return root_schema if ref == "#"

        seen = seen.merge(ref => true)
        return resolve_local(ref, root_schema, seen) if ref.start_with?("#/")
        return resolve_anchor(ref.delete_prefix("#"), root_schema) if ref.start_with?("#")

        resolve_remote(ref, root_schema, seen)
      end

      def resolve_local(ref, schema, seen = {})
        parts = ref.delete_prefix("#/").split("/", -1)
        current = schema

        parts.each do |part|
          current = navigate(current, decode_segment(part))
          # `false` is a valid boolean-schema target, so only nil is absent.
          return nil if current.nil?
        end

        return current unless current.is_a?(Schema)

        # Follow reference-form keywords at the target. `$dynamicRef` is
        # resolved statically against the document's anchors — an
        # approximation of dynamic scope that covers the common
        # meta-schema self-reference pattern.
        chained = current.dollar_ref || current.dollar_dynamic_ref ||
          current.dollar_recursive_ref
        chained ? resolve(chained, schema, seen) : current
      end

      # A non-pointer fragment names an anchor: `$anchor` (2019-09+), or
      # the draft-04 legacy `id: "#name"`.
      def resolve_anchor(name, schema)
        return nil unless schema

        find_anchor(schema, decode_segment(name), {}.compare_by_identity)
      end

      # Non-fragment refs resolve against the schema-set name map first,
      # then against the `$id` index built from the document tree
      # (relative ids join the nearest enclosing base, per RFC 3986).
      def resolve_remote(ref, root_schema = nil, seen = nil)
        mapped = schema_map_lookup(ref, seen)
        return mapped if mapped

        id_lookup(ref, root_schema)
      end

      # Depth-first walk over every schema node reachable from `schema`.
      def each_schema(schema, &)
        return unless schema.is_a?(Schema)

        yield schema
        schema.each_child { |child, _segment| each_schema(child, &) }
      end

      private

      def schema_map_lookup(ref, seen = nil)
        return nil unless @schemas

        file_path, fragment = ref.split("#", 2)
        candidates = [file_path, file_path.delete_prefix("./")]
        key = candidates.find { |candidate| @schemas[candidate] }
        return nil unless key

        schema = @schemas[key]
        return schema if fragment.nil? || fragment.empty?

        resolve("##{fragment}", schema, seen)
      end

      def id_lookup(ref, root_schema)
        return nil unless root_schema

        index = id_index(root_schema)
        base = root_schema.dollar_id
        [ref, ref.delete_prefix("./")].each do |candidate|
          found = index[absolutize(candidate, base)] || index[candidate]
          return found if found
        end
        nil
      end

      def id_index(root)
        @id_indexes ||= {}.compare_by_identity
        @id_indexes[root] ||= begin
          index = {}
          collect_ids(root, index, root.dollar_id)
          index
        end
      end

      def collect_ids(schema, index, base)
        return unless schema.is_a?(Schema)

        id = schema.dollar_id
        if id && !id.start_with?("#")
          absolute = absolutize(id, base)
          index[absolute] ||= schema
          index[id] ||= schema
          base = absolute
        end

        schema.each_child { |child, _segment| collect_ids(child, index, base) }
      end

      # RFC 3986 relative reference against a document base: keep the
      # base's directory, drop its last segment.
      def absolutize(id, base)
        return id if id.match?(%r{\A[a-z][a-z0-9+.-]*:}i)
        return id if base.nil? || base.empty?

        base_directory(base) + id
      end

      def base_directory(base)
        base.sub(%r{[^/]*\z}, "")
      end

      def navigate(current, part)
        case current
        when Schema
          current.child_at(part)
        when Array
          if part.match?(/\A\d+\z/)
            current[part.to_i]
          else
            entry = current.find do |e|
              e.is_a?(PropertyEntry) && e.name == part
            end
            entry&.schema_value
          end
        end
      end

      def find_anchor(schema, name, seen)
        return nil unless schema.is_a?(Schema)
        return nil if seen.key?(schema)

        seen[schema] = true
        return schema if schema.dollar_anchor == name
        return schema if schema.dollar_dynamic_anchor == name
        return schema if schema.dollar_id == "##{name}"

        schema.each_child do |child, _segment|
          found = find_anchor(child, name, seen)
          return found if found
        end
        nil
      end

      # RFC 6901: percent-decode the fragment, then unescape ~1 -> "/"
      # and finally ~0 -> "~" (order matters: "~01" decodes to "~1").
      def decode_segment(segment)
        bytes = segment.b.gsub(/%([0-9A-Fa-f]{2})/) do
          Regexp.last_match(1).hex.chr
        end
        bytes.force_encoding(Encoding::UTF_8).gsub("~1", "/").gsub("~0", "~")
      end
    end
  end
end
