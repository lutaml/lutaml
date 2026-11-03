module Expressir
  module ModelElementSpecHelper
    def check_nested_model_to_liquid(model, drop_model, result) # rubocop:disable Metrics/AbcSize
      model.class.attributes.each_key do |symbol|
        # Skip `parent` and `_class` attributes as they are not a part of the model
        next if ::Expressir::Model::ModelElement::SKIP_ATTRIBUTES.include?(symbol)

        value = model.send(symbol)
        drop_value = drop_model.send(symbol)

        case value
        when Array
          value.each_with_index do |v, i|
            dv = drop_value[i]

            if v.is_a? ::Expressir::Model::ModelElement
              check_nested_model_to_liquid(v, dv, result)
            elsif v.is_a?(::Expressir::Model::RemarkInfo)
              # Skip RemarkInfo comparisons - they're properly converted to drops,
              # but Drop equality comparison isn't implemented
              next
            else
              # puts "Expecting #{model.class.name} model_attr: #{symbol} " \
              #      "value: #{v} equals to #{drop_model.class.name} " \
              #      "model_attr: #{symbol} value: #{dv}"

              result << {
                model: model.class.name,
                attr: symbol,
                value: v,
                drop_model: drop_model.class.name,
                drop_value: dv,
              }
            end
          end.compact
        when ::Expressir::Model::ModelElement
          check_nested_model_to_liquid(value, drop_value, result)
        when ::Expressir::Model::RemarkInfo
          # Skip RemarkInfo comparisons - they're properly converted to drops,
          # but Drop equality comparison isn't implemented
          next
        else
          # puts "Expecting #{model.class.name} model_attr: #{attr} " \
          #      "value: #{value} equals to #{drop_model.class.name} " \
          #      "model_attr: #{attr} value: #{drop_value}"

          result << {
            model: model.class.name,
            attr: symbol,
            value: value,
            drop_model: drop_model.class.name,
            drop_value: drop_value,
          }
        end
      end
    end
  end
end
