# frozen_string_literal: true

module Lutaml
  module Uml
    # Shared helper methods for UML model objects.
    # These methods are used across transformers, serializers, and presenters
    # to avoid duplication of common model traversal and formatting logic.
    module ModelHelpers
      # Normalize a stereotype value to a consistent Array format.
      #
      # @param stereotype [String, Array, nil, Symbol] The stereotype value
      # @return [Array<String>] Array of stereotype strings
      #
      # @example
      #   normalize_stereotypes(nil)                    # => []
      #   normalize_stereotypes("enumeration")        # => ["enumeration"]
      #   normalize_stereotypes(["a", "b"])           # => ["a", "b"]
      #   normalize_stereotypes(:enumeration)         # => ["enumeration"]
      def normalize_stereotypes(stereotype)
        return [] if stereotype.nil?

        case stereotype
        when Array then stereotype.map(&:to_s)
        when String then [stereotype]
        when Symbol then [stereotype.to_s]
        else [stereotype.to_s]
        end
      end

      # Build a fully qualified name by walking the namespace chain of a UML element.
      #
      # @param uml_element [Lutaml::Uml::TopElement, Lutaml::Uml::Package] Any element with a namespace
      # @return [String] Fully qualified name joined by '::'
      #
      # @example
      #   qualified_name_for(class_in_package)  # => "ModelName::PackageName::ClassName"
      def qualified_name_for(uml_element)
        return uml_element.name unless uml_element.respond_to?(:namespace)

        parts = []
        current = uml_element

        while current
          parts.unshift(current.name) if current.name
          current = if current.respond_to?(:namespace) && current.namespace
                      current.namespace
                    else
                      break
                    end
        end

        parts.join("::")
      end

      # Build a package-only namespace path (no class names).
      #
      # @param uml_element [Lutaml::Uml::TopElement, Lutaml::Uml::Package]
      # @return [String] Package path joined by '::'
      #
      # @example
      #   package_path_for(class_in_nested_package)  # => "ModelName::ParentPackage::ChildPackage"
      def package_path_for(uml_element)
        return uml_element.name unless uml_element.respond_to?(:namespace)

        parts = []
        current = uml_element

        while current
          if current.is_a?(Lutaml::Uml::Package)
            parts.unshift(current.name) if current.name
            current = current.namespace if current.respond_to?(:namespace)
          elsif current.is_a?(Lutaml::Uml::TopElement)
            # Stop at the first TopElement (class, enum, etc.) — namespace above is package
            current = current.namespace if current.respond_to?(:namespace)
          else
            break
          end
        end

        parts.join("::")
      end

      # Extract the leaf class name from a fully-qualified class name or class object.
      #
      # @param uml_class [String, Class] A class name string or a Lutaml::Uml::* class instance
      # @return [String] The leaf class name
      #
      # @example
      #   class_type_for("Lutaml::Uml::Class")    # => "Class"
      #   class_type_for(some_enum_object)          # => "Enumeration"
      def class_type_for(uml_class)
        case uml_class
        when String then uml_class.split("::").last
        when Class then uml_class.name.split("::").last
        else uml_class.class.name.split("::").last
        end
      end

      # Format a cardinality object as a "min..max" string.
      #
      # @param cardinality [Lutaml::Uml::Cardinality, Hash, nil]
      # @return [String, nil] Formatted cardinality string or nil
      #
      # @example
      #   format_cardinality(Lutaml::Uml::Cardinality.new(min: 0, max: 5))  # => "0..5"
      #   format_cardinality({min: 1, max: nil})                           # => "1..*"
      def format_cardinality(cardinality)
        return nil unless cardinality

        min = cardinality.respond_to?(:min) ? cardinality.min : cardinality[:min]
        max = cardinality.respond_to?(:max) ? cardinality.max : cardinality[:max]
        return nil if min.nil? && max.nil?

        min_str = min.nil? ? "0" : min.to_s
        max_str = max.nil? ? "*" : max.to_s
        "#{min_str}..#{max_str}"
      end

      # Parse a cardinality string or hash into a {min:, max:} hash.
      #
      # @param min [String, nil]
      # @param max [String, nil]
      # @return [Hash{Symbol => String, nil}] Hash with :min and :max keys
      def parse_cardinality(min, max)
        {min: min, max: max}
      end
    end
  end
end
