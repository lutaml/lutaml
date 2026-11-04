# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class Generator
        def initialize(schema_set, output_path,
                       metadata: Metadata.new, strategy: nil, baseline: nil)
          @schema_set = schema_set
          @output_path = output_path
          @metadata = metadata
          @baseline = baseline
          @strategy = strategy || VueInlinedStrategy.new(@output_path)
        end

        def generate
          document = SpaBuilder.new(@schema_set, metadata: @metadata,
                                                 baseline: @baseline).build
          json_data = document.to_json
          @strategy.write(json_data)
        end
      end
    end
  end
end
