# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML Enumeration elements.
      #
      # Formats enumeration information including literal values.
      class EnumPresenter < ElementPresenter
        def initialize(element, repository = nil, context = nil)
          super
        end

        def to_text # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          lines = []
          lines << "Enumeration: #{element.name}"
          lines << ("=" * 50)
          lines << ""
          lines << "Name:          #{element.name}"
          if element.xmi_id
            lines << "XMI ID:        #{element.xmi_id}"
          end
          if element.stereotype && !element.stereotype.empty?
            lines << "Stereotype:    #{element.stereotype}"
          end
          if element.visibility
            lines << "Visibility:    #{element.visibility}"
          end
          lines << ""

          if element.values && !element.values.empty?
            lines << "Literal Values (#{element.values.size}):"
            element.values.each do |value| # rubocop:disable Style/HashEachMethods
              lines << "  - #{value.name || value.to_s}"
            end
          else
            lines << "Literal Values: (none)"
          end

          lines.join("\n")
        end

        def to_table_row
          value_count = element.values ? element.values.size : 0
          {
            type: "Enumeration",
            name: element.name || "(unnamed)",
            details: "#{value_count} literal value(s)",
          }
        end

        def to_hash # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          data = {
            type: "Enumeration",
            name: element.name,
            value_count: element.values ? element.values.size : 0,
          }

          data[:xmi_id] = element.xmi_id if element.xmi_id
          data[:stereotype] = element.stereotype if
            element.stereotype && !element.stereotype.empty?
          data[:visibility] = element.visibility if element.visibility

          if element.values && !element.values.empty?
            data[:values] = element.values.map do |v|
              v.name || v.to_s
            end
          end

          data
        end
      end

      # Register with factory
      PresenterFactory.register(Lutaml::Uml::Enum, EnumPresenter)
    end
  end
end
