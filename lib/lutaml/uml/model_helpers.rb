# frozen_string_literal: true

module Lutaml
  module Uml
    module ModelHelpers
      def normalize_stereotypes(stereotype)
        return [] if stereotype.nil?

        case stereotype
        when Array then stereotype.map(&:to_s)
        when String then [stereotype]
        when Symbol then [stereotype.to_s]
        else [stereotype.to_s]
        end
      end

      def qualified_name_for(uml_element)
        parts = []
        current = uml_element

        while current
          parts.unshift(current.name) if current.name
          current = current.namespace
        end

        parts.join("::")
      end

      def package_path_for(uml_element)
        parts = []
        current = uml_element

        while current
          if current.is_a?(Lutaml::Uml::Package)
            parts.unshift(current.name) if current.name
            current = current.namespace
          elsif current.is_a?(Lutaml::Uml::TopElement)
            current = current.namespace
          else
            break
          end
        end

        parts.join("::")
      end

      def class_type_for(uml_class)
        case uml_class
        when String
          uml_class.split("::").last
        when Lutaml::Uml::Enum
          "Enumeration"
        when Lutaml::Uml::DataType
          "DataType"
        when Lutaml::Uml::PrimitiveType
          "PrimitiveType"
        when Lutaml::Uml::Class
          "Class"
        when Class
          uml_class.name.split("::").last
        else
          uml_class.class.name.split("::").last
        end
      end

      def format_cardinality(cardinality)
        return nil unless cardinality

        min = cardinality.min
        max = cardinality.max
        return nil if min.nil? && max.nil?

        min_str = min.nil? ? "0" : min.to_s
        max_str = max.nil? ? "*" : max.to_s
        "#{min_str}..#{max_str}"
      end

      def parse_cardinality(min, max)
        { min: min, max: max }
      end

      def format_definition(definition, options = {})
        return nil if definition.nil? || definition.empty?

        formatted = definition.strip
        if options[:max_definition_length] &&
            formatted.length > options[:max_definition_length]
          formatted = "#{formatted[0...options[:max_definition_length]]}..."
        end
        if options[:format_definitions]
          formatted = formatted.gsub(%r{(https?://[^\s]+)}, '[\1](\1)')
        end
        formatted
      end

      def extract_package_path(qualified_name, default: "")
        parts = qualified_name.to_s.split("::")
        return default if parts.size <= 1

        parts[0..-2].join("::")
      end
    end
  end
end
