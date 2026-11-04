# frozen_string_literal: true

require "json"
require "yeptris"
require "yeptris/yaml"

module Lutaml
  module Jsonschema
    # Reads a schema source file into JSON text for `Schema.from_json`.
    #
    # `.json` files are returned byte-for-byte. `.yaml`/`.yml` files hold
    # YAML-encoded JSON Schema: they are safe-loaded (no aliases, no Ruby
    # classes), checked to contain only JSON-compatible values, and
    # re-emitted as JSON so the schema goes through the same JSON keyword
    # mapping. Scalar typing is the YAML 1.1 behaviour of the underlying
    # Psych-backed loader (unquoted `yes`/`no` are booleans; unquoted
    # dates and symbols are rejected) — quote such values.
    module SourceFile
      class InvalidYamlError < Error; end

      YAML_EXTENSIONS = %w[.yaml .yml].freeze
      DIRECTORY_GLOB = "*.{json,yaml,yml}"

      module_function

      def yaml?(path)
        YAML_EXTENSIONS.include?(File.extname(path.to_s).downcase)
      end

      # Returns `[schema, source_json]`.
      def load(path)
        source = read(path)
        [Schema.from_json(source), source]
      end

      def read(path)
        data = File.read(path, encoding: "utf-8")
        return data unless yaml?(path)

        yaml_to_json(data, path)
      end

      def yaml_to_json(data, path = nil)
        value = safe_load_yaml(data, path)
        check_json_compatible!(value, path, "")
        JSON.pretty_generate(value)
      end

      def safe_load_yaml(data, path)
        Yeptris::YAML.safe_load(data, permitted_classes: [], aliases: false)
      rescue StandardError => e
        raise InvalidYamlError, "#{path || 'YAML source'}: #{e.message}"
      end

      def check_json_compatible!(value, path, pointer)
        case value
        when Hash
          check_mapping!(value, path, pointer)
        when Array
          check_sequence!(value, path, pointer)
        when Float
          invalid!(path, pointer, "non-finite number") unless value.finite?
        when String, Integer, true, false, nil
          nil
        else
          invalid!(path, pointer, "unsupported value #{value.class}")
        end
      end

      def check_mapping!(mapping, path, pointer)
        mapping.each do |key, child|
          unless key.is_a?(String)
            invalid!(path, pointer, "non-string mapping key #{key.inspect}")
          end
          check_json_compatible!(child, path, "#{pointer}/#{escape(key)}")
        end
      end

      def check_sequence!(sequence, path, pointer)
        sequence.each_with_index do |child, index|
          check_json_compatible!(child, path, "#{pointer}/#{index}")
        end
      end

      def escape(key)
        key.gsub("~", "~0").gsub("/", "~1")
      end

      def invalid!(path, pointer, message)
        location = pointer.empty? ? "/" : pointer
        raise InvalidYamlError,
              "#{path || 'YAML source'} at #{location}: #{message} " \
              "is not JSON-compatible"
      end
    end
  end
end
