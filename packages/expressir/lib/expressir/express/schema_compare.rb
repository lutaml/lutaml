# frozen_string_literal: true

module Expressir
  module Express
    # Structural diff of two schemata with a machine-applicable patch
    # (TODO.eengine/07; eeng --compare/--patch semantics, plugin/p11
    # compare entry). Declarations match by canonical path
    # `schema.item`; entity attributes get their own sub-deltas at
    # `schema.item.attribute` carrying types, optionality and
    # aggregates inside the signature.
    #
    # Interfaces are out of scope: the patch target is a flattened
    # (longform) schema, which has none.
    module SchemaCompare
      # `node` carries the revised declaration for :added and :changed
      # (nil for :removed) so {SchemaPatch.apply} can rebuild.
      # `classification` is set by {ChangeClassification.apply}.
      Delta = Struct.new(:op, :path, :node, :classification, keyword_init: true)

      # Resolution artifacts and presentation metadata are not part of
      # a declaration's structure.
      SIGNATURE_IGNORE = %w[source include_source remarks remark_items
                            ref base_path file].freeze

      COLLECTIONS = %i[constants types entities subtype_constraints
                       functions rules procedures].freeze

      NODE_COLLECTION = {
        "Expressir::Model::Declarations::Constant" => :constants,
        "Expressir::Model::Declarations::Type" => :types,
        "Expressir::Model::Declarations::Entity" => :entities,
        "Expressir::Model::Declarations::SubtypeConstraint" => :subtype_constraints,
        "Expressir::Model::Declarations::Function" => :functions,
        "Expressir::Model::Declarations::Rule" => :rules,
        "Expressir::Model::Declarations::Procedure" => :procedures,
      }.freeze

      module_function

      def compare(base, revised)
        COLLECTIONS.flat_map { |collection| collection_deltas(base, revised, collection) }
      end

      def collection_deltas(base, revised, collection)
        base_items = index(base, collection)
        revised_items = index(revised, collection)
        deltas = (revised_items.keys - base_items.keys).map do |path|
          Delta.new(op: :added, path: path, node: revised_items[path])
        end
        (base_items.keys - revised_items.keys).each do |path|
          deltas << Delta.new(op: :removed, path: path, node: nil)
        end
        (base_items.keys & revised_items.keys).each do |path|
          old_item = base_items[path]
          new_item = revised_items[path]
          next if signature(old_item) == signature(new_item)

          deltas << Delta.new(op: :changed, path: path, node: new_item)
          next unless new_item.is_a?(Model::Declarations::Entity)

          deltas.concat(attribute_deltas(old_item, new_item, path))
        end
        deltas
      end

      def attribute_deltas(old_item, new_item, path)
        old_attrs = index_by_id(Array(old_item.attributes))
        new_attrs = index_by_id(Array(new_item.attributes))
        deltas = (new_attrs.keys - old_attrs.keys).map do |name|
          Delta.new(op: :added, path: "#{path}.#{name}",
                    node: new_attrs[name])
        end
        (old_attrs.keys - new_attrs.keys).each do |name|
          deltas << Delta.new(op: :removed, path: "#{path}.#{name}", node: nil)
        end
        (old_attrs.keys & new_attrs.keys).each do |name|
          next if signature(old_attrs[name]) == signature(new_attrs[name])

          deltas << Delta.new(op: :changed, path: "#{path}.#{name}",
                              node: new_attrs[name])
        end
        deltas
      end

      def index_by_id(items)
        items.filter_map { |item| [item.id&.downcase, item] if item.id }.to_h
      end

      def index(schema, collection)
        index_by_id(Array(schema.send(collection)))
          .transform_keys { |key| "#{schema.id.downcase}.#{key}" }
      end

      def signature(node)
        strip(node.to_hash)
      end

      def strip(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, inner), out|
            next if SIGNATURE_IGNORE.include?(key.to_s)

            out[key] = strip(inner)
          end
        when Array then value.map { |inner| strip(inner) }
        else value
        end
      end
    end

    # Applies {SchemaCompare} deltas to a schema model, returning the
    # revised schema. The base schema is deep-copied through the
    # lutaml-model round trip; the input schema is never mutated.
    module SchemaPatch
      module_function

      def apply(base, deltas)
        revised = base.class.from_hash(base.to_hash)
        item_deltas, attribute_deltas = deltas.partition do |delta|
          delta.path.split(".").size == 2
        end
        item_deltas.each { |delta| apply_item(revised, delta) }
        # An item-level :added/:changed node already carries the final
        # attribute list; its sub-deltas are informational only.
        replaced_ops = %i[added changed].freeze
        replaced = item_deltas
          .select { |delta| replaced_ops.include?(delta.op) }
          .map(&:path)
        attribute_deltas
          .reject { |delta| replaced.include?(delta.path.split(".")[0..1].join(".")) }
          .each { |delta| apply_attribute(revised, delta) }
        revised
      end

      def apply_item(schema, delta)
        item_key = delta.path.split(".").last.downcase
        collection = if delta.op == :added
                       schema.send(SchemaCompare::NODE_COLLECTION.fetch(delta.node.class.name))
                     else
                       live_collection(schema, item_key)
                     end
        return unless collection

        case delta.op
        when :added then collection << delta.node
        when :removed then collection.delete_if { |item| key(item) == item_key }
        when :changed
          index = collection.index { |item| key(item) == item_key }
          return unless index

          collection.delete_at(index)
          collection.insert(index, delta.node)
        end
      end

      def apply_attribute(schema, delta)
        segments = delta.path.split(".")
        item = SchemaCompare.index_by_id(all_declarations(schema))[segments[1].downcase]
        return unless item

        attr_key = segments[2]
        attrs = Array(item.attributes)
        case delta.op
        when :added
          item.attributes = [*attrs, delta.node]
        when :removed
          item.attributes = attrs.reject { |attr| key(attr) == attr_key }
        when :changed
          index = attrs.index { |attr| key(attr) == attr_key }
          return unless index

          item.attributes = attrs
          item.attributes.delete_at(index)
          item.attributes.insert(index, delta.node)
        end
      end

      def live_collection(schema, item_key)
        SchemaCompare::COLLECTIONS.map { |name| schema.send(name) }
          .find do |collection|
          Array(collection).any? { |item| key(item) == item_key }
        end
      end

      def all_declarations(schema)
        SchemaCompare::COLLECTIONS.flat_map { |name| Array(schema.send(name)) }
      end

      def key(item)
        item.id&.downcase
      end
    end
  end
end
