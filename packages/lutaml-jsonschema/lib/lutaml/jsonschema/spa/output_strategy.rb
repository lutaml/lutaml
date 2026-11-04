# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class OutputStrategy
        def initialize(output_path)
          @output_path = output_path
        end

        def write(_json_data)
          raise NotImplementedError
        end
      end
    end
  end
end
