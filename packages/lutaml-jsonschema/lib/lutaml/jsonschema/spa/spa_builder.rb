# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class SpaBuilder
        def initialize(schema_set, metadata: nil, baseline: nil)
          @schema_set = schema_set
          @metadata = metadata || Metadata.new
          @baseline = baseline
        end

        def build
          infer_metadata_title if @metadata.title.nil?

          schemas = build_schemas
          search_index = build_search_index(schemas)

          SpaDocument.new(
            metadata: @metadata,
            schemas: schemas,
            search_index: search_index,
            diff: build_diff,
          )
        end

        private

        def infer_metadata_title
          first_schema = @schema_set.schemas.values.first
          @metadata.title = first_schema&.title if first_schema&.title
        end

        def build_schemas
          @schema_set.schemas.to_a.map do |name, schema|
            build_spa_schema(name, schema)
          end
        end

        # Changes against a baseline set, per schema name, classified by
        # consumer impact (Diff's breaking/additive/cosmetic).
        def build_diff
          return [] unless @baseline

          @schema_set.schemas.flat_map do |name, schema|
            previous = @baseline.schemas[name]
            next [] unless previous

            Diff.between(previous, schema).map do |change|
              SpaDiffEntry.new(schema_name: name,
                               pointer: change.pointer,
                               classification: change.classification.to_s,
                               detail: change.detail)
            end
          end
        end

        def build_spa_schema(name, schema)
          all_props = collect_all_properties(schema)
          all_defs = collect_all_definitions(schema)
          all_required = collect_all_required(schema)

          props_with_source = collect_all_properties_with_source(schema)
          source_map = props_with_source.to_h { |entry, src| [entry.name, src] }

          properties = build_properties(all_props, schema, all_required,
                                        source_map)
          definitions = build_definitions_from_entries(all_defs, schema)

          if_info = resolve_if_schema(schema)
          features = resolve_schema_features(schema, schema)

          SpaSchema.new(
            name: name,
            title: schema.title,
            description: schema.description,
            type: schema.type,
            properties: properties,
            definitions: definitions,
            required: all_required,
            examples: schema.examples,
            source_json: @schema_set.source_json(name) || "",
            dollar_schema: schema.dollar_schema,
            dollar_id: schema.dollar_id,
            external_docs: schema.external_docs,
            discriminator: schema.discriminator,
            additional_properties: schema.additional_properties,
            min_properties: schema.min_properties,
            max_properties: schema.max_properties,
            has_all_of: schema.all_of.any?,
            has_any_of: schema.any_of.any?,
            has_one_of: schema.one_of.any?,
            **property_items_fields(features),
            if_schema: if_info[:if_prop],
            then_required: if_info[:then_required],
            then_properties: if_info[:then_properties],
            else_properties: if_info[:else_properties],
            pattern_properties: features[:pattern_properties],
            contains_type: features[:contains_type],
            contains_ref: features[:contains_ref],
            not_type: features[:not_type],
            links: features[:links],
          )
        end

        def collect_all_properties_with_source(schema, context_schema = schema)
          inherited = []
          composition_schemas_with_source(schema).each do |s, source|
            resolved = resolve_composition_schema(s, context_schema)
            inherited.concat(collect_all_properties_with_source(resolved,
                                                                context_schema).map do |entry, src|
              [entry, src || source]
            end)
          end
          own = schema.property_entries.dup.map { |e| [e, nil] }
          deduplicated_merge_with_source(inherited, own)
        end

        def collect_all_properties(schema, context_schema = schema)
          inherited = []
          composition_schemas(schema).each do |s|
            resolved = resolve_composition_schema(s, context_schema)
            inherited.concat(collect_all_properties(resolved, context_schema))
          end
          own = schema.property_entries.dup
          deduplicated_merge(inherited, own)
        end

        def collect_all_definitions(schema, context_schema = schema)
          inherited = []
          composition_schemas(schema).each do |s|
            resolved = resolve_composition_schema(s, context_schema)
            inherited.concat(collect_all_definitions(resolved, context_schema))
          end
          own = schema.definition_entries.dup
          deduplicated_merge(inherited, own)
        end

        def collect_all_required(schema, context_schema = schema)
          required = schema.required.dup
          composition_schemas(schema).each do |s|
            resolved = resolve_composition_schema(s, context_schema)
            required.concat(collect_all_required(resolved, context_schema))
          end
          required
        end

        def resolve_composition_schema(schema, context_schema)
          schema = as_schema(schema)
          return schema unless schema.dollar_ref

          as_schema(@schema_set.resolve_ref(schema.dollar_ref,
                                            context_schema)) || schema
        end

        # Boolean schemas (`true` = anything, `false` = nothing) and
        # TupleItem wrappers appear wherever a schema can; normalize them
        # to a renderable Schema.
        def as_schema(value)
          value = value.value if value.is_a?(TupleItem)
          return value if value.is_a?(Schema)
          return nil if value.nil?

          Schema.new(type: value ? "any" : "never")
        end

        def composition_schemas(schema)
          schema.all_of + schema.any_of + schema.one_of
        end

        def composition_schemas_with_source(schema)
          result = schema.all_of.map { |s| [s, "allOf"] }
          schema.any_of.each { |s| result << [s, "anyOf"] }
          schema.one_of.each { |s| result << [s, "oneOf"] }
          result
        end

        def deduplicated_merge_with_source(inherited, own)
          seen = {}
          all = inherited + own
          all.each_with_index do |pair, idx|
            seen[pair[0].name] = idx
          end
          seen.values.sort.map { |i| all[i] }
        end

        def deduplicated_merge(inherited, own)
          seen = {}
          all = inherited + own
          all.each_with_index do |entry, idx|
            seen[entry.name] = idx
          end
          seen.values.sort.map { |i| all[i] }
        end

        # Resolves a definition schema that may be a bare $ref, an
        # allOf-merged $ref, a oneOf/anyOf union, or a plain schema.
        def resolve_definition_schema(s, root_schema)
          # Case 1: bare $ref (e.g. Abstract_DistributionUnion → #MD_Distribution)
          if s.dollar_ref && !s.type && s.property_entries.empty? &&
              s.one_of.empty? && s.all_of.empty? && s.any_of.empty?
            resolved = as_schema(@schema_set.resolve_ref(s.dollar_ref,
                                                         root_schema))
            return resolved if resolved
          end

          # Case 2: allOf with a single $ref and no own properties
          if s.all_of.length == 1 && !s.type && s.property_entries.empty?
            item = s.all_of.first
            ref = item.is_a?(TupleItem) ? item.schema&.dollar_ref : item.dollar_ref
            if ref
              resolved = as_schema(@schema_set.resolve_ref(ref, root_schema))
              return resolved if resolved
            end
          end

          # Otherwise return as-is
          s
        end

        def build_definitions_from_entries(entries, root_schema)
          entries.filter_map do |entry|
            s = as_schema(entry.schema_value)
            next unless s

            resolved = resolve_definition_schema(s, root_schema)

            all_props = collect_all_properties(resolved)
            all_required = collect_all_required(resolved)
            properties = build_properties(all_props, root_schema, all_required)

            ap_info = resolve_additional_properties(resolved, root_schema)
            variants = resolve_composition_variants(resolved, root_schema)
            features = resolve_schema_features(resolved, root_schema)

            SpaDefinition.new(
              **extract_schema_constraints(resolved),
              name: entry.name,
              title: resolved.title || s.title,
              description: resolved.description || s.description,
              properties: properties,
              required: all_required,
              additional_properties: resolved.additional_properties,
              additional_properties_ref: ap_info[:ref],
              additional_properties_type: ap_info[:type],
              has_all_of: resolved.all_of.any? || s.all_of.any?,
              has_any_of: resolved.any_of.any? || s.any_of.any?,
              has_one_of: resolved.one_of.any? || s.one_of.any?,
              composition_variants: variants,
              **property_items_fields(features),
              contains_type: features[:contains_type],
              contains_ref: features[:contains_ref],
              pattern_properties: features[:pattern_properties],
              not_type: features[:not_type],
              one_of_variants: build_variant_list(resolved.one_of, root_schema),
              any_of_variants: build_variant_list(resolved.any_of, root_schema),
              discriminator: resolved.discriminator || s.discriminator,
              links: features[:links],
            )
          end
        end

        def resolve_additional_properties(schema, root_schema)
          ap_schema = schema.additional_properties_schema
          return { ref: nil, type: nil } unless ap_schema

          if ap_schema.dollar_ref
            ref = ap_schema.dollar_ref
            resolved = as_schema(@schema_set.resolve_ref(ref, root_schema))
            { ref: ref,
              type: resolved&.type || resolved&.title }
          else
            { ref: nil, type: ap_schema.type }
          end
        end

        # Returns a hash of common constraint fields shared by SpaProperty and
        # SpaDefinition, extracted from a resolved schema.
        def extract_schema_constraints(resolved)
          {
            title: resolved.title,
            description: resolved.description,
            type: resolved.type,
            format: resolved.format,
            default: resolved.default,
            pattern: resolved.pattern,
            enum: resolved.enum,
            enum_descriptions: resolved.enum_descriptions,
            min_length: resolved.min_length,
            max_length: resolved.max_length,
            minimum: resolved.minimum,
            maximum: resolved.maximum,
            exclusive_minimum: resolved.exclusive_minimum_value,
            exclusive_maximum: resolved.exclusive_maximum_value,
            multiple_of: resolved.multiple_of,
            content_type: resolved.content_type,
            content_encoding: resolved.content_encoding,
            const_value: resolved.const,
            examples: resolved.examples,
            additional_properties: resolved.additional_properties,
            min_properties: resolved.min_properties,
            max_properties: resolved.max_properties,
          }
        end

        # Item-schema fields shared by SpaProperty and SpaDefinition.
        def property_items_fields(features)
          {
            items_type: features[:items_info][:type],
            items_ref: features[:items_info][:ref],
            items_properties: features[:items_detail][:properties],
            items_required: features[:items_detail][:required],
            items_enum: features[:items_detail][:enum],
            items_format: features[:items_detail][:format],
            items_tuple: features[:items_tuple],
            items_tail: features[:items_tail],
            items_closed: features[:items_closed],
          }
        end

        # Bundles all schema feature resolutions (items, contains,
        # patternProperties, not, links) into a single hash.
        def resolve_schema_features(resolved, root_schema, depth = 0)
          {
            items_info: resolve_items_info(resolved, root_schema),
            items_detail: build_items_detail(resolved, root_schema, depth),
            items_tuple: resolve_items_tuple(resolved, root_schema),
            items_tail: resolve_items_tail(resolved, root_schema),
            items_closed: resolved.items_closed?,
            contains_type: resolve_contains_type(resolved),
            contains_ref: resolve_contains_ref(resolved),
            pattern_properties: build_pattern_properties(resolved),
            not_type: resolve_not_type(resolved),
            links: build_links(resolved),
          }
        end

        def resolve_composition_variants(schema, root_schema)
          variants = []
          schema.one_of.each do |sub|
            resolved = resolve_composition_schema(sub, root_schema)
            variants << type_label(resolved)
          end
          schema.any_of.each do |sub|
            resolved = resolve_composition_schema(sub, root_schema)
            variants << type_label(resolved)
          end
          variants.compact
        end

        def build_properties(entries, root_schema,
                            all_required = root_schema.required,
                            source_map = nil, depth = 0)
          properties = entries.map do |entry|
            source = source_map ? source_map[entry.name] : nil
            build_single_property(entry, root_schema, all_required, source,
                                  depth)
          end
          order_properties(properties, all_required)
        end

        # Configuration-driven ordering (Redoc sort options): alphabetical
        # or required-first; anything else keeps source order.
        # Nested detail only descends three levels deep; deeper nesting
        # stays in the JSON viewer.
        def build_children(resolved, root_schema, depth)
          return [[], [], []] if depth >= 3

          [
            build_nested_properties(resolved, root_schema),
            collect_all_required(resolved),
            build_nested_definitions(resolved, root_schema),
          ]
        end

        # Dialect-dependent display verdicts (TODO.sota/04): `$ref`
        # siblings and the `format` assertion split.
        def dialect_display_fields(source_schema, resolved, dialect)
          siblings = source_schema.ref_with_siblings?
          {
            ref_siblings_ignored: siblings && Dialect.ignore_ref_siblings?(dialect),
            ref_siblings_apply: siblings && !Dialect.ignore_ref_siblings?(dialect),
            format_assertion: resolved.format && Dialect.format_asserts?(dialect),
          }
        end

        def order_properties(properties, required)
          case @metadata&.sort_properties
          when "alphabetical"
            properties.sort_by { |property| property.name.to_s.downcase }
          when "required_first"
            properties.each_with_index
              .sort_by do |property, index|
                [required.include?(property.name) ? 0 : 1, index]
              end
              .map(&:first)
          else
            properties
          end
        end

        def build_single_property(entry, root_schema, all_required,
                                  composition_source = nil, depth = 0)
          source_schema = as_schema(entry.schema_value)
          resolved = resolve_property(entry, root_schema)
          # the dialect is a document-level fact: it rides the root
          # schema, not the property (which carries no `$schema`)
          dialect = root_schema.dialect

          resolved = resolve_ref_chain(resolved, root_schema)

          # Capture oneOf/anyOf from the pre-resolution schema for variant detail
          pre_comp_one_of = resolved.one_of.any? ? resolved.one_of.dup : source_schema.one_of.dup
          pre_comp_any_of = resolved.any_of.any? ? resolved.any_of.dup : source_schema.any_of.dup
          original_not_type = original_not_type_for(resolved, source_schema)

          if !resolved.type && composition_schema?(source_schema)
            resolved = resolve_composition_property(source_schema,
                                                    root_schema) || resolved
          end

          if !resolved.type && composition_schema?(resolved)
            comp = resolve_composition_property(resolved, root_schema)
            resolved = comp if comp
          end

          resolved = infer_type_from_const(resolved) unless resolved.type

          resolved = empty_schema_fallback(resolved) unless resolved.type

          prop_ref = resolve_prop_ref(source_schema)
          features = resolve_schema_features(resolved, root_schema, depth)

          nested, nested_required, nested_defs = build_children(resolved,
                                                                root_schema,
                                                                depth)

          ap_info = resolve_additional_properties(resolved, root_schema)
          SpaProperty.new(
            **extract_schema_constraints(resolved),
            name: entry.name,
            required: all_required.include?(entry.name),
            ref: prop_ref,
            **dialect_display_fields(source_schema, resolved, dialect),
            deprecated: resolved.deprecated,
            read_only: resolved.read_only,
            write_only: resolved.write_only,
            min_items: resolved.min_items,
            max_items: resolved.max_items,
            unique_items: resolved.unique_items,
            composition_source: composition_source,
            properties: nested,
            required_fields: nested_required,
            definitions: nested_defs,
            additional_properties_ref: ap_info[:ref],
            additional_properties_type: ap_info[:type],
            **property_items_fields(features),
            contains_type: features[:contains_type],
            contains_ref: features[:contains_ref],
            pattern_properties: features[:pattern_properties],
            one_of_variants: if depth < 2
                               build_variant_list(pre_comp_one_of,
                                                  root_schema)
                             else
                               []
                             end,
            any_of_variants: if depth < 2
                               build_variant_list(pre_comp_any_of,
                                                  root_schema)
                             else
                               []
                             end,
            discriminator: source_schema.discriminator || resolved.discriminator,
            not_type: original_not_type,
            links: features[:links],
          )
        end

        def infer_type_from_const(schema)
          return schema unless schema.const && !schema.type

          Schema.new(
            type: "string",
            title: schema.title,
            description: schema.description,
            const: schema.const,
            format: schema.format,
          )
        end

        # A typeless schema is unrestricted, but it may still carry
        # constraints (bounds, enum, pattern) or applicators — default the
        # rendered type without discarding them.
        def empty_schema_fallback(schema)
          fallback = schema.dup
          fallback.type = "any"
          fallback
        end

        def resolve_items_info(resolved, root_schema)
          items = resolved.items
          return { type: nil, ref: nil } unless items.is_a?(Schema)

          if items.dollar_ref
            ref = items.dollar_ref
            resolved_items = as_schema(@schema_set.resolve_ref(ref,
                                                               root_schema))
            if resolved_items
              { type: resolved_items.type || resolved_items.title, ref: ref }
            else
              { type: nil, ref: ref }
            end
          elsif items.one_of.any? || items.any_of.any?
            { type: composition_type_label(items, root_schema), ref: nil }
          else
            { type: items.type, ref: nil }
          end
        end

        def composition_type_label(schema, root_schema)
          return nil unless schema.one_of.any? || schema.any_of.any?

          subs = schema.one_of.any? ? schema.one_of : schema.any_of
          prefix = schema.one_of.any? ? "oneOf" : "anyOf"
          labels = subs.filter_map do |sub|
            resolved = resolve_composition_schema(sub, root_schema)
            type_label(resolved) if resolved
          end
          labels.empty? ? nil : "#{prefix}: #{labels.join(' | ')}"
        end

        # Positional labels for tuple item schemas, from either the tuple
        # drafts' `items` array or 2020-12 `prefixItems`.
        def resolve_items_tuple(resolved, root_schema)
          tuple = resolved.tuple_items
          return nil unless tuple

          tuple.map { |item| tuple_item_label(item, root_schema) }
        end

        def tuple_item_label(item, root_schema)
          return "any" if item == true
          return "never" if item == false

          ref = item.dollar_ref
          if ref
            target = as_schema(@schema_set.resolve_ref(ref, root_schema))
            target&.title || target&.type || ref.split("/").last
          else
            composition_type_label(item, root_schema) ||
              item.title || item.type || "any"
          end
        end

        def resolve_items_tail(resolved, root_schema)
          tail = resolved.items_tail_schema
          return nil unless tail

          tuple_item_label(tail, root_schema)
        end

        def resolve_prop_ref(schema)
          return schema.dollar_ref if schema.dollar_ref

          return nil unless schema.all_of.any?

          schema.all_of
            .filter_map do |item|
              item.is_a?(TupleItem) ? item.schema&.dollar_ref : item.dollar_ref
            end
            .first
        end

        def resolve_property(entry, root_schema)
          schema = as_schema(entry.schema_value)
          return schema unless schema.dollar_ref

          as_schema(@schema_set.resolve_ref(schema.dollar_ref,
                                            root_schema)) || schema
        end

        # Follow a chain of bare $ref schemas (A → B → C).
        # Stops when the schema has a type, properties, or is not a bare $ref.
        def resolve_ref_chain(schema, root_schema, depth = 0)
          return schema if depth > 5
          return schema unless schema.dollar_ref
          return schema if schema.type || schema.property_entries.any?
          return schema if schema.one_of.any? || schema.all_of.any? || schema.any_of.any?

          resolved = as_schema(@schema_set.resolve_ref(schema.dollar_ref,
                                                       root_schema))
          return schema unless resolved

          resolve_ref_chain(resolved, root_schema, depth + 1)
        end

        def composition_schema?(schema)
          schema.all_of.any? || schema.any_of.any? ||
            schema.one_of.any? || schema.not_value
        end

        def resolve_composition_property(schema, root_schema)
          if schema.all_of.any?
            resolve_all_of_property(schema, root_schema)
          elsif schema.any_of.any?
            resolve_any_of_property(schema, root_schema)
          elsif schema.one_of.any?
            resolve_one_of_property(schema, root_schema)
          elsif schema.not_value
            resolve_not_property(schema, root_schema)
          end
        end

        def resolve_all_of_property(schema, root_schema)
          merged_type = nil
          merged_properties = schema.property_entries.dup
          merged_required = schema.required.dup
          merged_title = schema.title
          merged_description = schema.description

          schema.all_of.each do |sub|
            resolved = resolve_composition_schema(sub, root_schema)
            merged_type ||= resolved.type
            merged_title ||= resolved.title
            merged_description ||= resolved.description
            merged_properties.concat(resolved.property_entries)
            merged_required.concat(resolved.required)
          end

          return nil unless merged_type

          Schema.new(
            type: merged_type,
            title: merged_title,
            description: merged_description,
            property_entries: merged_properties,
            required: merged_required,
            additional_properties: schema.additional_properties,
            min_properties: schema.min_properties,
            max_properties: schema.max_properties,
          )
        end

        def resolve_any_of_property(schema, root_schema)
          resolve_variant_property("anyOf", schema.any_of, root_schema,
                                   schema.description)
        end

        def resolve_one_of_property(schema, root_schema)
          resolve_variant_property("oneOf", schema.one_of, root_schema,
                                   schema.description)
        end

        def resolve_variant_property(prefix, subs, root_schema, description)
          variant_types = subs.filter_map do |sub|
            resolved = resolve_composition_schema(sub, root_schema)
            type_label(resolved)
          end.compact

          return nil if variant_types.empty?

          Schema.new(
            type: "#{prefix}: #{variant_types.join(' | ')}",
            description: description,
          )
        end

        def resolve_not_property(schema, _root_schema)
          negated = as_schema(schema.not_value)
          negated_type = negated&.type || "any"
          Schema.new(
            type: "not #{negated_type}",
            description: schema.description,
          )
        end

        def type_label(schema)
          title = schema.title
          type = schema.type
          if title
            type ? "#{title} (#{type})" : title
          elsif type
            type
          end
        end

        # ── Nested property building ──

        def build_nested_properties(resolved, _root_schema, depth = 0)
          return [] unless object_type?(resolved)

          all_props = collect_all_properties(resolved)
          all_required = collect_all_required(resolved)
          build_properties(all_props, resolved, all_required, nil, depth)
        end

        def build_nested_definitions(resolved, _root_schema, _depth = 0)
          return [] unless object_type?(resolved)

          all_defs = collect_all_definitions(resolved)
          build_definitions_from_entries(all_defs, resolved)
        end

        def object_type?(schema)
          schema.type && schema.types.include?("object")
        end

        # ── Items detail ──

        def build_items_detail(resolved, root_schema, depth = 0)
          items = resolved.items
          return {} unless items.is_a?(Schema)

          items_resolved = if items.dollar_ref
                             @schema_set.resolve_ref(items.dollar_ref,
                                                     root_schema) || items
                           else
                             items
                           end

          result = {}
          if object_type?(items_resolved) && depth < 3
            all_props = collect_all_properties(items_resolved)
            all_required = collect_all_required(items_resolved)
            result[:properties] = build_properties(all_props, items_resolved,
                                                   all_required, nil, depth + 1)
            result[:required] = all_required
          end
          result[:enum] = items_resolved.enum if items_resolved.enum&.any?
          result[:format] = items_resolved.format if items_resolved.format
          result
        end

        # ── Composition variant schemas ──

        def build_variant_list(sub_schemas, root_schema, depth = 0)
          return [] if depth > 2

          sub_schemas.filter_map do |sub|
            source_ref = sub.is_a?(TupleItem) ? sub.schema&.dollar_ref : sub.dollar_ref
            resolved = resolve_composition_schema(sub, root_schema)
            next unless resolved

            nested = if depth < 2
                       build_nested_properties(resolved,
                                               root_schema)
                     else
                       []
                     end
            nested_required = depth < 2 ? collect_all_required(resolved) : []

            SpaProperty.new(
              title: resolved.title,
              description: resolved.description,
              type: resolved.type,
              ref: source_ref || resolved.dollar_ref,
              const_value: resolved.const,
              enum: resolved.enum,
              enum_descriptions: resolved.enum_descriptions,
              format: resolved.format,
              properties: nested,
              required_fields: nested_required,
              minimum: resolved.minimum,
              maximum: resolved.maximum,
              pattern: resolved.pattern,
            )
          end
        end

        # ── Contains ──

        def resolve_contains_type(schema)
          c = as_schema(schema.contains_value)
          return nil unless c

          if c.dollar_ref
            resolved = @schema_set.resolve_ref(c.dollar_ref, schema)
            resolved&.type || c.type
          else
            c.type
          end
        end

        def resolve_contains_ref(schema)
          as_schema(schema.contains_value)&.dollar_ref
        end

        # ── patternProperties ──

        def build_pattern_properties(schema)
          return nil unless schema.pattern_property_entries&.any?

          schema.pattern_property_entries.each_with_object({}) do |entry, hash|
            hash[entry.name] = { "type" => as_schema(entry.schema_value)&.type }.compact
          end
        end

        # ── not ──

        def resolve_not_type(schema)
          value = schema.not_value
          return nil if value.nil?
          return value ? "any" : "never" unless value.is_a?(Schema)

          value.type || "any"
        end

        def original_not_type_for(resolved, source_schema)
          [resolved, source_schema].filter_map do |schema|
            resolve_not_type(schema)
          end.first
        end

        # ── if/then/else ──

        def resolve_if_schema(schema)
          result = { if_prop: nil, then_required: [], then_properties: [],
                     else_properties: [] }

          # `if: false` never fires, so it is equivalent to no condition.
          return result unless schema.if_value

          result[:if_prop] = if_property(schema, as_schema(schema.if_value))
          then_value = as_schema(schema.then_value)
          result.merge!(then_branch(schema, then_value)) if then_value
          else_value = as_schema(schema.else_value)
          if else_value
            result[:else_properties] = branch_properties(schema, else_value)
          end
          result
        end

        def if_property(schema, if_schema)
          if_props = collect_all_properties(if_schema)
          SpaProperty.new(
            title: "When condition is met",
            properties: if_props.any? ? build_properties(if_props, schema, []) : [],
          )
        end

        def then_branch(schema, then_schema)
          then_props = collect_all_properties(then_schema)
          required = collect_all_required(then_schema)
          properties = if then_props.any?
                         build_properties(then_props, schema, required)
                       else
                         required.map { |name| SpaProperty.new(name: name, required: true) }
                       end
          { then_required: required, then_properties: properties }
        end

        def branch_properties(schema, branch)
          props = collect_all_properties(branch)
          props.any? ? build_properties(props, schema, []) : []
        end

        # ── Links (hyper-schema) ──

        def build_links(schema)
          return [] unless schema.links&.any?

          schema.links.map do |link|
            SpaLink.new(
              title: link.title,
              description: link.description,
              http_method: link.http_method,
              href: link.href,
              rel: link.rel,
            )
          end
        end

        def build_search_index(schemas)
          schemas.flat_map do |spa_schema|
            entries = [SpaSearchEntry.new(
              name: spa_schema.name,
              title: spa_schema.title,
              description: spa_schema.description,
              type: "schema",
              schema_name: spa_schema.name,
            )]

            spa_schema.properties.each do |prop|
              entries << SpaSearchEntry.new(
                name: prop.name,
                title: prop.title,
                description: prop.description,
                type: "property",
                schema_name: spa_schema.name,
              )
            end

            spa_schema.definitions.each do |defn|
              entries << SpaSearchEntry.new(
                name: defn.name,
                title: defn.title,
                description: defn.description,
                type: "definition",
                schema_name: spa_schema.name,
              )

              defn.properties.each do |prop|
                entries << SpaSearchEntry.new(
                  name: prop.name,
                  title: prop.title,
                  description: prop.description,
                  type: "property",
                  schema_name: spa_schema.name,
                )
              end
            end

            entries
          end
        end
      end
    end
  end
end
