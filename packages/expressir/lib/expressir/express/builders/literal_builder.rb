# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds literal nodes (integer, real, binary, logical, string).
      class LiteralBuilder
        include ::Expressir::Express::Builders::Helpers

        # Integer literal
        def build_integer(ast_data)
          val = extract_text(ast_data[:integer] || ast_data[:str])
          Expressir::Model::Literals::Integer.new(value: val)
        end

        # Real literal
        def build_real(ast_data)
          val = extract_text(ast_data[:real] || ast_data[:str])
          Expressir::Model::Literals::Real.new(value: val)
        end

        # Binary literal
        def build_binary(ast_data)
          val = extract_text(ast_data[:binary] || ast_data[:str])
          Expressir::Model::Literals::Binary.new(value: val)
        end

        # Logical literal
        def build_logical(ast_data)
          value = if ast_data[:t_true]
                    Expressir::Model::Literals::Logical::TRUE
                  elsif ast_data[:t_false]
                    Expressir::Model::Literals::Logical::FALSE
                  elsif ast_data[:t_unknown]
                    Expressir::Model::Literals::Logical::UNKNOWN
                  else
                    val = extract_text(ast_data[:logical] || ast_data[:str]).to_s.strip.upcase
                    case val
                    when "TRUE" then Expressir::Model::Literals::Logical::TRUE
                    when "FALSE" then Expressir::Model::Literals::Logical::FALSE
                    else Expressir::Model::Literals::Logical::UNKNOWN
                    end
                  end
          Expressir::Model::Literals::Logical.new(value: value)
        end

        # String literal
        def build_string(ast_data)
          if ast_data[:string_literal] && ast_data.keys.length == 1
            ast_data = ast_data[:string_literal]
          end

          if ast_data[:simple_string_literal].is_a?(Hash)
            build_simple_string(ast_data[:simple_string_literal])
          elsif ast_data[:encoded_string_literal].is_a?(Hash)
            build_encoded_string(ast_data[:encoded_string_literal])
          else
            val = extract_text(ast_data[:str])
            val = val[1..-2] if val && val.length >= 2
            Expressir::Model::Literals::String.new(value: val)
          end
        end

        def build_simple_string(ast_data)
          val = extract_text(ast_data[:str])
          val = val[1..-2] if val && val.length >= 2
          Expressir::Model::Literals::String.new(value: val)
        end

        def build_encoded_string(ast_data)
          val = extract_text(ast_data[:str])
          val = val[1..-2] if val && val.length >= 2
          Expressir::Model::Literals::String.new(value: val, encoded: true)
        end

        # Generic literal dispatcher
        def call(ast_data)
          if ast_data[:binary_literal]
            Builder.build({ binary_literal: ast_data[:binary_literal] })
          elsif ast_data[:integer_literal]
            Builder.build({ integer_literal: ast_data[:integer_literal] })
          elsif ast_data[:logical_literal]
            Builder.build({ logical_literal: ast_data[:logical_literal] })
          elsif ast_data[:real_literal]
            Builder.build({ real_literal: ast_data[:real_literal] })
          elsif ast_data[:string_literal]
            Builder.build({ string_literal: ast_data[:string_literal] })
          end
        end
      end
    end
  end
end
