# frozen_string_literal: true

module Expressir
  module Express
    # Structural traversal over model trees, mirroring {ModelVisitor}:
    # every typed attribute, statements included. Nodes are keyed by
    # attribute path plus array index — stable across a compiled-set
    # round trip because the wire is byte-identical — which is what the
    # remark and reference overlays key on ({Model::ModelElement#path}
    # is empty for id-less nodes).
    module ModelTraversal
      module_function

      def each_node(node, key, &block)
        yield node, key
        return unless node.is_a?(Model::ModelElement)

        node.class.attributes.each_key do |attr|
          next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr) || attr == :parent

          value = node.public_send(attr)
          case value
          when Array
            value.each_with_index do |item, index|
              next unless item.is_a?(Model::ModelElement)

              each_node(item, "#{key}/#{attr}[#{index}]", &block)
            end
          when Model::ModelElement
            each_node(value, "#{key}/#{attr}", &block)
          end
        end
      end

      def each_model(models, &block)
        models.each_with_index do |model, index|
          each_node(model, "model[#{index}]", &block)
        end
      end
    end
  end
end
