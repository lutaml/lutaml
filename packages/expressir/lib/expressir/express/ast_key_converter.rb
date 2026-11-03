# frozen_string_literal: true

module Expressir
  module Express
    # Converts native-AST CamelCase keys to the snake_case keys the
    # builders consume.
    #
    # build() descends into child nodes whose subtrees the parent already
    # converted, so unchanged containers are marked with an invisible
    # instance variable and skipped on re-visits — without it, every
    # subtree is re-scanned once per ancestor level (~60 convert calls per
    # model node on real schemas). The marker is invisible to equality,
    # hashing, and inspection.
    class AstKeyConverter
      SNAKED_MARKER = :@_expressir_keys_snaked
      UPPERCASE_PATTERN = /[A-Z]/

      class << self
        # Thread-local snake_case conversion cache. Thread-local avoids the
        # mutable-constant anti-pattern while remaining thread-safe. The
        # cache is bounded by the number of unique AST node-type names.
        def snake_case(name)
          cache[name] ||= begin
            str = name.to_s
            if /^[a-z_]+$/.match?(str)
              str.to_sym
            else
              str
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .to_sym
            end
          end
        end

        # Returns the original object when no conversion is needed; the
        # common no-conversion case allocates nothing and the conversion
        # case walks the keys once.
        def convert(obj)
          case obj
          when Hash
            return obj if obj.empty?
            return obj if obj.instance_variable_defined?(SNAKED_MARKER)

            keys = obj.keys
            converted_values = nil
            new_keys = nil

            keys.each_with_index do |k, i|
              val = obj[k]
              case val
              when Hash, Array
                unless val.empty?
                  converted_val = convert(val)
                  (converted_values ||= {})[k] = converted_val unless converted_val.equal?(val)
                end
              end

              if k.match?(UPPERCASE_PATTERN)
                (new_keys ||= keys.dup)[i] = snake_case(k)
              end
            end

            return mark_snaked(obj) unless new_keys || converted_values

            result = {}
            keys.each_with_index do |k, i|
              key = new_keys&.[](i) || k
              result[key] = converted_values&.key?(k) ? converted_values[k] : obj[k]
            end
            mark_snaked(result)
          when Array
            return obj if obj.empty?
            return obj if obj.instance_variable_defined?(SNAKED_MARKER)

            needs_conversion = false
            result = []

            obj.each do |item|
              case item
              when Hash, Array
                next if item.empty?

                converted = convert(item)
                result << converted
                needs_conversion = true unless converted.equal?(item)
              else
                result << item
              end
            end

            needs_conversion ? mark_snaked(result) : mark_snaked(obj)
          else
            obj
          end
        end

        private

        def cache
          Thread.current[:expressir_snake_case_cache] ||= {}
        end

        def mark_snaked(obj)
          obj.instance_variable_set(SNAKED_MARKER, true)
          obj
        rescue FrozenError
          obj
        end
      end
    end
  end
end
