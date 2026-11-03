module Expressir
  module Express
    module Formatters
      module ReferencesFormatter
        def self.included(base)
          base.register_formatter Model::References::AttributeReference,
                                  :format_references_attribute_reference
          base.register_formatter Model::References::GroupReference,
                                  :format_references_group_reference
          base.register_formatter Model::References::IndexReference,
                                  :format_references_index_reference
          base.register_formatter Model::References::SimpleReference,
                                  :format_references_simple_reference
        end

        def format_references_attribute_reference(node)
          [
            format(node.ref),
            ".",
            format(node.attribute),
          ].join
        end

        def format_references_group_reference(node)
          [
            format(node.ref),
            "\\",
            format(node.entity),
          ].join
        end

        def format_references_index_reference(node)
          [
            format(node.ref),
            "[",
            format(node.index1),
            *if node.index2
               [
                 ":",
                 format(node.index2),
               ].join
             end,
            "]",
          ].join
        end

        def format_references_simple_reference(node)
          node.id
        end
      end
    end
  end
end
