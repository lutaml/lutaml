# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds unique_rule nodes.
      class UniqueRuleBuilder
        def call(ast_data)
          inner_data = ast_data[:unique_rule] || ast_data

          id = Builder.build_optional(inner_data[:rule_label_id])

          if inner_data[:list_of_referenced_attribute]
            attrs_data = inner_data[:list_of_referenced_attribute]
            if attrs_data.is_a?(Hash)
              ref_attrs = attrs_data[:referenced_attribute]
              ref_attrs = [ref_attrs] unless ref_attrs.is_a?(Array)
              attributes = ref_attrs.filter_map do |attr|
                Builder.build({ referenced_attribute: attr })
              end
            else
              attributes = Builder.build_children(attrs_data)
            end
          else
            attributes = Builder.build_children(inner_data[:referenced_attribute])
          end

          attributes = attributes.compact

          # The grammar's separator repetition can yield a phantom rule
          # fragment (no label, no referenced attributes) between real
          # rules; drop it so clean never emits a bare ";" (GH-340).
          return nil if id.nil? && attributes.empty?

          Expressir::Model::Declarations::UniqueRule.new(id: id,
                                                         attributes: attributes)
        end
      end
    end
  end
end
