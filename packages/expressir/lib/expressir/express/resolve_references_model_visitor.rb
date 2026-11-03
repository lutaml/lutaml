module Expressir
  module Express
    class ResolveReferencesModelVisitor < ModelVisitor
      def visit(node)
        if node.is_a? Model::References::SimpleReference
          visit_references_simple_reference(node)
        end

        super
      end

      private

      def visit_references_simple_reference(node)
        return if node.parent.is_a? Model::References::AttributeReference
        return unless node.id # Skip if no id to resolve

        base_item = if node.parent.is_a? Model::Declarations::InterfaceItem
                      node.find("#{node.parent.parent.schema.id}.#{node.parent.ref.id}")
                    else
                      node.find(node.id)
                    end
        return unless base_item

        node.base_path = base_item.path
      end
    end
  end
end
