# frozen_string_literal: true

module Expressir
  module Express
    # Remarks are deterministic given the sources, so the batch path
    # persists them as an overlay next to the compiled-set artifact;
    # warm loads re-apply the overlay instead of re-running the
    # {RemarkAttacher}.
    #
    # Nodes are keyed structurally — attribute path plus array index —
    # because {Model::ModelElement#path} is empty for id-less nodes
    # (statements), and the wire is byte-identical between the cold
    # write and the warm apply, so structural keys match exactly.
    module RemarkOverlay
      CAPTURED = %w[remarks remark_items informal_propositions untagged_remarks header].freeze

      class << self
        def write(set_path, models)
          overlay = {}
          ModelTraversal.each_model(models) do |node, key|
            entry = {}
            CAPTURED.each do |attr|
              next unless node.respond_to?(attr)

              value = node.public_send(attr)
              entry[attr] = value if attr == "header" ? value : value&.any?
            end
            overlay[key] = entry if entry.any?
          end
          return if overlay.empty?

          require "json"
          File.write("#{set_path}.remarks.json", JSON.generate(overlay))
        end

        # Recursively parent restored nodes and invalidate id-memos so
        # find()/resolve_path_in_scope sees them, exactly as the
        # RemarkAttacher's own bookkeeping does.
        def wire_overlay_value(parent, value)
          case value
          when Array
            value.each { |item| wire_overlay_value(parent, item) }
          when Model::ModelElement
            parent_value = parent.is_a?(Model::ModelElement) ? parent : nil
            value.parent = parent_value if value.respond_to?(:parent=)
            if parent_value.respond_to?(:reset_children_by_id)
              parent_value.reset_children_by_id
            end
            value.class.attributes.each_key do |attr|
              next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr) || attr == :parent

              inner = value.public_send(attr)
              next unless inner.is_a?(Model::ModelElement) || inner.is_a?(Array)

              wire_overlay_value(value, inner)
            end
          end
        end

        def apply(set_path, models)
          overlay_path = "#{set_path}.remarks.json"
          return unless File.exist?(overlay_path)

          require "json"
          overlay = JSON.parse(File.read(overlay_path))
          ModelTraversal.each_model(models) do |node, key|
            entry = overlay[key]
            next unless entry

            CAPTURED.each do |attr|
              setter = :"#{attr}="
              next unless entry[attr] && node.respond_to?(setter)

              node.public_send(setter, entry[attr])
              # The writer casts JSON hashes into model objects; wire
              # the cast collection (the attacher parents every
              # created node and resets the child-id memo — reference
              # resolution relies on both).
              wire_overlay_value(node, node.public_send(attr))
            end
          end
        end
      end
    end
  end
end
