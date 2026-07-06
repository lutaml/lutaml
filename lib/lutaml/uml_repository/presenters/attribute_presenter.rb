# frozen_string_literal: true

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
          if (line = resolved_type_line)
            lines << line
          end
          lines << "Cardinality:   #{format_cardinality(element)}"
          if element.visibility
            lines << "Visibility:    #{element.visibility}"
          end
          if element.stereotype && !element.stereotype.empty?
            lines << "Stereotype:    #{element.stereotype}"
          end
          lines << "Is Derived:    #{element.is_derived}"
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

          if element.visibility
            data[:visibility] = element.visibility
          end
          if element.stereotype
            data[:stereotype] = element.stereotype
          end
          data[:is_derived] = element.is_derived

          if (resolution = resolved_type)
            data[:resolved_type] = resolution.qualified_name
            data[:resolved_type_primitive] = resolution.primitive?
            data[:resolved_type_ambiguous] = resolution.ambiguous?
            data[:resolved_type_candidates] = resolution.candidates
          end

          data
        end

        private

        # Resolve the attribute's type to its target class, when the owning
        # class context and a repository are available. Returns the resolver
        # Result or nil (so context-less callers keep their original output).
        def resolved_type
          owner = @context["class_qname"] || @context[:class_qname]
          return nil unless owner && element.type
          return nil unless @repository.is_a?(Lutaml::UmlRepository::Repository)

          @repository.resolve_type(element.type, from: owner)
        end

        # Human-readable "Resolved Type:" line, or nil when there is nothing
        # useful to show (unresolved, or no context).
        def resolved_type_line
          resolution = resolved_type
          return nil unless resolution
          return "Resolved Type:  (primitive)" if resolution.primitive?
          return nil unless resolution.resolved?
          # Already-qualified type that resolves to itself: nothing to add.
          return nil if resolution.qualified_name == element.type

          suffix = if resolution.ambiguous?
                     " (ambiguous: #{resolution.candidates.size} candidates)"
                   else
                     ""
                   end
          "Resolved Type:  #{resolution.qualified_name}#{suffix}"
        end

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
