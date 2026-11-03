# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds schema_version_id nodes into SchemaVersion objects.
      class SchemaVersionBuilder
        def call(ast_data)
          string_val = Builder.build_optional(ast_data[:string_literal])
          value = string_val.is_a?(Expressir::Model::Literals::String) ? string_val.value : string_val.to_s

          items = nil
          if value.start_with?("{") && value.end_with?("}")
            parts = value[1..-2].split
            items = parts.map do |part|
              if (match = part.match(/^(.+)\((\d+)\)$/))
                Expressir::Model::Declarations::SchemaVersionItem.new(
                  name: match[1], value: match[2],
                )
              elsif /^\d+$/.match?(part)
                Expressir::Model::Declarations::SchemaVersionItem.new(value: part)
              else
                Expressir::Model::Declarations::SchemaVersionItem.new(name: part)
              end
            end
          end

          Expressir::Model::Declarations::SchemaVersion.new(value: value,
                                                            items: items)
        end
      end
    end
  end
end
