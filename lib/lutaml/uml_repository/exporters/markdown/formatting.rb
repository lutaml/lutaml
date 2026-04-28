# frozen_string_literal: true

require_relative "../../../uml/model_helpers"

module Lutaml
  module UmlRepository
    module Exporters
      module Markdown
        module Formatting
          include Lutaml::Uml::ModelHelpers

          def format_cardinality(cardinality)
            return "" unless cardinality

            min = cardinality.min || "0"
            max = cardinality.max || "*"
            "#{min}..#{max}"
          end

          def format_stereotypes(stereotype)
            return "" unless stereotype

            case stereotype
            when Array
              stereotype.join(", ")
            when String
              stereotype
            else
              ""
            end
          end
        end
      end
    end
  end
end
