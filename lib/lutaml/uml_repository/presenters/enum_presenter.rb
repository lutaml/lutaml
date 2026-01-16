# frozen_string_literal: true

require_relative "element_presenter"
require_relative "presenter_factory"

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
          if element.respond_to?(:xmi_id) && element.xmi_id
            lines << "XMI ID:        #{element.xmi_id}"
          end
          if element.respond_to?(:stereotype) && element.stereotype
            lines << "Stereotype:    #{element.stereotype}"
          end
          if element.respond_to?(:visibility) && element.visibility
            lines << "Visibility:    #{element.visibility}"
          end
          lines << ""

          if element.values && !element.values.empty?
            lines << "Literal Values (#{element.values.size}):"
            element.each_value do |value|
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

          data[:xmi_id] = element.xmi_id if
            element.respond_to?(:xmi_id) && element.xmi_id
          data[:stereotype] = element.stereotype if
            element.respond_to?(:stereotype) && element.stereotype
          data[:visibility] = element.visibility if
            element.respond_to?(:visibility) && element.visibility

          if element.values && !element.values.empty?
            data[:values] = element.values.map do |v|
              v.respond_to?(:name) ? v.name : v.to_s
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
