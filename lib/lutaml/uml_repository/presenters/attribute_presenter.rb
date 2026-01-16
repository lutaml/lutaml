# frozen_string_literal: true

require_relative "element_presenter"
require_relative "presenter_factory"

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML Attribute elements.
      #
      # Formats attribute information including type, cardinality, and owning
      # class.
      class AttributePresenter < ElementPresenter
        def initialize(element, repository = nil, context = nil)
          super
        end

        def to_text # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          lines = []
          lines << "Attribute: #{qualified_name}"
          lines << ("=" * 50)
          lines << ""
          lines << "Name:          #{element.name}"
          lines << "Class:         #{class_name}"
          lines << "Type:          #{element.type || 'Unknown'}"
          lines << "Cardinality:   #{format_cardinality(element)}"
          if element.respond_to?(:visibility) && element.visibility
            lines << "Visibility:    #{element.visibility}"
          end
          if element.respond_to?(:stereotype) && element.stereotype
            lines << "Stereotype:    #{element.stereotype}"
          end
          if element.respond_to?(:is_derived)
            lines << "Is Derived:    #{element.is_derived}"
          end
          lines.join("\n")
        end

        def to_table_row
          {
            type: "Attribute",
            name: element.name || "(unnamed)",
            details: "#{class_name}::#{element.name} : #{element.type}",
          }
        end

        def to_hash # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          data = {
            type: "Attribute",
            name: element.name,
            class_name: class_name,
            attr_type: element.type,
            cardinality: format_cardinality(element),
          }

          if element.respond_to?(:visibility)
            data[:visibility] = element.visibility
          end
          if element.respond_to?(:stereotype)
            data[:stereotype] = element.stereotype
          end
          if element.respond_to?(:is_derived)
            data[:is_derived] = element.is_derived
          end

          data
        end

        private

        def class_name
          @context["class_name"] ||
            @context[:class_name] || extract_class_from_qname
        end

        def qualified_name
          @context["qualified_name"] ||
            @context[:qualified_name] || "#{class_name}::#{element.name}"
        end

        def extract_class_from_qname
          qname = @context["class_qname"] || @context[:class_qname]
          return "Unknown" unless qname

          parts = qname.split("::")
          parts.last
        end
      end

      # Register with factory
      PresenterFactory.register(
        Lutaml::Uml::TopElementAttribute,
        AttributePresenter,
      )
      # Also register common attribute base class
      if defined?(Lutaml::Uml::Attribute)
        PresenterFactory.register(Lutaml::Uml::Attribute, AttributePresenter)
      end
    end
  end
end
