# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds data type nodes (enumeration, select, array, bag, list, set, etc.).
      class TypeBuilder
        include ::Expressir::Express::Builders::Helpers

        def build_boolean_type(_ast_data)
          Expressir::Model::DataTypes::Boolean.new
        end

        def build_integer_type(_ast_data)
          Expressir::Model::DataTypes::Integer.new
        end

        def build_logical_type(_ast_data)
          Expressir::Model::DataTypes::Logical.new
        end

        def build_number_type(_ast_data)
          Expressir::Model::DataTypes::Number.new
        end

        # String type
        def build_string_type(ast_data)
          width = Builder.build_optional(ast_data[:width_spec]&.dig(:width))
          fixed = !ast_data[:width_spec]&.dig(:t_fixed).nil?
          kwargs = { width: width }
          kwargs[:fixed] = fixed if fixed
          Expressir::Model::DataTypes::String.new(**kwargs)
        end

        # Binary type
        def build_binary_type(ast_data)
          width = Builder.build_optional(ast_data[:width_spec]&.dig(:width))
          fixed = !ast_data[:width_spec]&.dig(:t_fixed).nil?
          kwargs = { width: width }
          kwargs[:fixed] = fixed if fixed
          Expressir::Model::DataTypes::Binary.new(**kwargs)
        end

        # Real type
        def build_real_type(ast_data)
          precision = Builder.build_optional(ast_data[:precision_spec])
          if precision
            Expressir::Model::DataTypes::Real.new(precision: precision)
          else
            Expressir::Model::DataTypes::Real.new
          end
        end

        # Aggregate type (AGGREGATE OF type)
        def build_aggregate_type(ast_data)
          base_type = Builder.build_optional(ast_data[:parameter_type])
          Expressir::Model::DataTypes::Aggregate.new(base_type: base_type)
        end

        # Aggregation types
        def build_array_type(ast_data)
          build_aggregation_type(ast_data, Expressir::Model::DataTypes::Array)
        end

        def build_bag_type(ast_data)
          build_aggregation_type(ast_data, Expressir::Model::DataTypes::Bag)
        end

        def build_list_type(ast_data)
          build_aggregation_type(ast_data, Expressir::Model::DataTypes::List)
        end

        def build_set_type(ast_data)
          build_aggregation_type(ast_data, Expressir::Model::DataTypes::Set)
        end

        def build_general_set_type(ast_data)
          build_general_aggregation_type(ast_data, Expressir::Model::DataTypes::Set)
        end

        def build_general_list_type(ast_data)
          build_general_aggregation_type(ast_data, Expressir::Model::DataTypes::List)
        end

        def build_general_bag_type(ast_data)
          build_general_aggregation_type(ast_data, Expressir::Model::DataTypes::Bag)
        end

        def build_general_array_type(ast_data)
          build_general_aggregation_type(ast_data, Expressir::Model::DataTypes::Array)
        end

        def build_aggregation_type(ast_data, type_class)
          bound_spec = ast_data[:bound_spec] || {}
          bound1 = Builder.build_optional(bound_spec[:bound1])
          bound2 = Builder.build_optional(bound_spec[:bound2])
          optional = !ast_data[:t_optional].nil?
          unique = !ast_data[:t_unique].nil?
          base_type = Builder.build_optional(ast_data[:instantiable_type])

          type_class.new(
            bound1: bound1,
            bound2: bound2,
            optional: optional,
            unique: unique,
            base_type: base_type,
          )
        end

        # General aggregation types (used in parameter types)
        # These use parameter_type instead of instantiable_type
        def build_general_aggregation_type(ast_data, type_class)
          bound_spec = ast_data[:bound_spec] || {}
          bound1 = Builder.build_optional(bound_spec[:bound1])
          bound2 = Builder.build_optional(bound_spec[:bound2])
          base_type = Builder.build_optional(ast_data[:parameter_type])
          # Element modifiers are legal on general aggregations too
          # (attributes and parameters); dropping them silently changed
          # element constraints (GH-338). ARRAY carries both flags,
          # LIST only UNIQUE, per the model.
          optional = !ast_data[:t_optional].nil? if type_class.method_defined?(:optional)
          unique = !ast_data[:t_unique].nil? if type_class.method_defined?(:unique)

          type_class.new(
            bound1: bound1,
            bound2: bound2,
            optional: optional,
            unique: unique,
            base_type: base_type,
          )
        end

        # Enumeration type
        def build_enumeration_type(ast_data)
          extensible = !ast_data[:t_extensible].nil?
          items = []
          based_on = nil

          if ast_data[:enumeration_items].is_a?(Hash)
            items_data = ast_data[:enumeration_items][:list_of_enumeration_item] ||
              ast_data[:enumeration_items][:enumeration_item]
            if items_data
              items_data = items_data[:enumeration_item] if items_data.is_a?(Hash) && items_data[:enumeration_item]
              items_data = [items_data] unless items_data.is_a?(Array)
              items = items_data.filter_map do |item|
                actual_item = item.is_a?(Hash) ? (item[:enumeration_item] || item) : item
                Builder.build({ enumeration_item: actual_item })
              end
            end
          elsif ast_data[:enumeration_extension].is_a?(Hash)
            # Wrap type_ref data so the correct handler is called
            type_ref_data = ast_data[:enumeration_extension][:type_ref]
            based_on = Builder.build({ type_ref: type_ref_data }) if type_ref_data

            if ast_data[:enumeration_extension][:enumeration_items].is_a?(Hash)
              items_data = ast_data[:enumeration_extension][:enumeration_items][:list_of_enumeration_item] ||
                ast_data[:enumeration_extension][:enumeration_items][:enumeration_item]
              if items_data
                items_data = items_data[:enumeration_item] if items_data.is_a?(Hash) && items_data[:enumeration_item]
                items_data = [items_data] unless items_data.is_a?(Array)
                items = items_data.filter_map do |item|
                  actual_item = item.is_a?(Hash) ? (item[:enumeration_item] || item) : item
                  Builder.build({ enumeration_item: actual_item })
                end
              end
            end
          end

          kwargs = { based_on: based_on, items: items }
          kwargs[:extensible] = extensible if extensible
          Expressir::Model::DataTypes::Enumeration.new(**kwargs)
        end

        # Enumeration item
        def build_enumeration_item(ast_data)
          id = nil
          if ast_data.is_a?(Hash)
            if ast_data[:enumeration_id]
              enum_id_data = ast_data[:enumeration_id]
              id = if enum_id_data.is_a?(Hash)
                     extract_text(enum_id_data[:str]) || extract_text(enum_id_data[:simple_id]&.dig(:str))
                   else
                     enum_id_data.to_s
                   end
            elsif ast_data[:simple_id]
              id = extract_text(ast_data[:simple_id]&.dig(:str)) || extract_text(ast_data[:str])
            elsif ast_data[:str]
              id = extract_text(ast_data[:str])
            end
          elsif ast_data.is_a?(String)
            id = ast_data
          end
          Expressir::Model::DataTypes::EnumerationItem.new(id: id)
        end

        # Select type
        def build_select_type(ast_data)
          extensible = !ast_data[:t_extensible].nil?
          generic_entity = !ast_data[:t_generic_entity].nil?
          items = []
          based_on = nil

          if ast_data[:select_list].is_a?(Hash)
            named_types = ast_data[:select_list][:list_of_named_types]
            items = Builder.build_children(named_types) if named_types
          elsif ast_data[:select_extension].is_a?(Hash)
            # Wrap type_ref data so the correct handler is called
            if ast_data[:select_extension][:type_ref]
              based_on = Builder.build({ type_ref: ast_data[:select_extension][:type_ref] })
            end
            if ast_data[:select_extension][:select_list].is_a?(Hash)
              named_types = ast_data[:select_extension][:select_list][:list_of_named_types]
              items = Builder.build_children(named_types) if named_types
            end
          end

          kwargs = { based_on: based_on, items: items.compact }
          kwargs[:extensible] = extensible if extensible
          kwargs[:generic_entity] = generic_entity if generic_entity
          Expressir::Model::DataTypes::Select.new(**kwargs)
        end

        # Type wrappers - choice types that dispatch to inner type
        def build_type_wrapper(ast_data)
          return nil unless ast_data.is_a?(Hash)

          ast_data.each do |k, v|
            next unless v

            result = Builder.build({ k => v })
            return result if result
          end
          nil
        end
      end
    end
  end
end
