# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Shared helper methods for all builders.
      # Included as a module to avoid duplication.
      module Helpers
        # Extract text from Parsanol::Slice or return as-is
        def extract_text(val)
          return nil unless val
          return val.to_s if val.is_a?(String)
          return val.to_s if val.is_a?(Symbol)
          return val.to_s if val.is_a?(Parsanol::Slice)

          if val.is_a?(Hash)
            str = val[:str]
            return str.to_s if str
          end
          val
        end

        # Get first value from a hash (for union types)
        def first_value(hash)
          return nil unless hash.is_a?(Hash)

          hash.values.first
        end

        # Recursively extract text from nested structures
        def extract_nested_text(data)
          return nil unless data
          return data.to_s if data.is_a?(String)
          return data.to_s if data.is_a?(Symbol)
          return data.to_s if data.is_a?(Parsanol::Slice)

          if data.is_a?(Hash)
            str = data[:str]
            return str.to_s if str

            data.each_value do |value|
              result = extract_nested_text(value)
              return result if result
            end
          elsif data.is_a?(Array)
            data.each do |item|
              result = extract_nested_text(item)
              return result if result
            end
          end
          nil
        end

        # Extract ID from reference types like functionId, constantId, etc.
        def extract_id_ref(data)
          id_data = data[:function_id] || data[:constant_id] || data[:parameter_id] ||
            data[:variable_id] || data[:attribute_id] || data[:entity_id] ||
            data[:type_id] || data[:procedure_id] || data[:schema_id] ||
            data[:type_label_id] || data[:enumeration_id] || data[:rename_id] ||
            data[:simple_id]

          extract_nested_text(id_data || first_value(data))
        end

        # Extract interval operator
        def extract_interval_op(data)
          return nil unless data

          if data.is_a?(Array)
            data.each do |item|
              next unless item.is_a?(Hash)
              return "LESS_THAN" if item[:op_less_than]
              return "LESS_THAN_OR_EQUAL" if item[:op_less_equal]
            end
            nil
          elsif data.is_a?(Hash)
            return "LESS_THAN" if data[:op_less_than]
            return "LESS_THAN_OR_EQUAL" if data[:op_less_equal]

            nil
          end
        end

        # Extract binary operator
        def extract_operator(data)
          return nil unless data
          return :ADDITION if data[:op_plus]
          return :SUBTRACTION if data[:op_minus]
          return :OR if data[:t_or]
          return :XOR if data[:t_xor]
          return :MULTIPLICATION if data[:op_asterisk]
          return :REAL_DIVISION if data[:op_slash]
          return :INTEGER_DIVISION if data[:t_div]
          return :MODULO if data[:t_mod]
          return :AND if data[:t_and]
          return :COMBINE if data[:op_double_pipe]

          extract_text(first_value(data))&.upcase&.to_sym
        end

        # Extract unary operator
        def extract_unary_op(data)
          return nil unless data
          return :PLUS if data[:op_plus]
          return :MINUS if data[:op_minus]
          return :NOT if data[:t_not]

          extract_text(first_value(data))&.upcase&.to_sym
        end

        # Extract relational operator
        def extract_rel_op(data)
          return nil unless data
          return :EQUAL if data[:t_equal] || data[:op_equals]
          return :NOT_EQUAL if data[:t_not_equal] || data[:op_less_greater]
          return :LESS_THAN if data[:t_less_than] || data[:op_less_than]
          return :GREATER_THAN if data[:t_greater_than] || data[:op_greater_than]
          return :LESS_THAN_OR_EQUAL if data[:t_less_than_or_equal] || data[:op_less_equal]
          return :GREATER_THAN_OR_EQUAL if data[:t_greater_than_or_equal] || data[:op_greater_equal]
          return :INSTANCE_EQUAL if data[:t_instance_equal] || data[:op_colon_equals_colon]
          return :INSTANCE_NOT_EQUAL if data[:t_instance_not_equal] || data[:op_colon_less_greater_colon]

          extract_text(first_value(data))&.upcase&.to_sym
        end

        # Apply qualifier to reference
        def apply_qualifier(ref, qualifier)
          case qualifier
          when Expressir::Model::References::AttributeReference
            Expressir::Model::References::AttributeReference.new(ref: ref,
                                                                 attribute: qualifier.attribute)
          when Expressir::Model::References::GroupReference
            Expressir::Model::References::GroupReference.new(ref: ref,
                                                             entity: qualifier.entity)
          when Expressir::Model::References::IndexReference
            Expressir::Model::References::IndexReference.new(ref: ref,
                                                             index1: qualifier.index1, index2: qualifier.index2)
          when Expressir::Model::References::SimpleReference
            Expressir::Model::References::AttributeReference.new(ref: ref,
                                                                 attribute: qualifier)
          else
            ref
          end
        end
      end
    end
  end
end
