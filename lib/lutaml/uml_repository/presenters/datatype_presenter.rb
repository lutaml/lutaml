# frozen_string_literal: true

require_relative "element_presenter"
require_relative "presenter_factory"

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML DataType elements.
      #
      # Formats data type information including attributes and operations.
      class DataTypePresenter < ElementPresenter
        def initialize(element, repository = nil, context = nil)
          super
        end

        def to_text # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          lines = []
          lines << "DataType: #{element.name}"
          lines << ("=" * 50)
          lines << ""
          lines << "Name:          #{element.name}"
          if element.respond_to?(:xmi_id) && element.xmi_id
            lines << "XMI ID:        #{element.xmi_id}"
          end
          if element.respond_to?(:type) && element.type
            lines << "Type:          #{element.type}"
          end
          if element.respond_to?(:stereotype) && element.stereotype
            lines << "Stereotype:    #{element.stereotype}"
          end
          if element.respond_to?(:visibility) && element.visibility
            lines << "Visibility:    #{element.visibility}"
          end
          if element.respond_to?(:is_abstract)
            lines << "Abstract:      #{element.is_abstract}"
          end
          lines << ""

          if element.attributes && !element.attributes.empty?
            lines << "Attributes (#{element.attributes.size}):"
            element.attributes.each do |attr|
              type_info = attr.type ? " : #{attr.type}" : ""
              lines << "  - #{attr.name}#{type_info}"
            end
            lines << ""
          end

          if element.respond_to?(:operations) && element.operations &&
              !element.operations.empty?
            lines << "Operations (#{element.operations.size}):"
            element.operations.each do |op|
              lines << "  - #{op.name}()"
            end
          end

          lines.join("\n")
        end

        def to_table_row
          attr_count = element.attributes ? element.attributes.size : 0
          {
            type: "DataType",
            name: element.name || "(unnamed)",
            details: "#{attr_count} attribute(s)",
          }
        end

        def to_hash # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          data = {
            type: "DataType",
            name: element.name,
          }

          data[:xmi_id] = element.xmi_id if
            element.respond_to?(:xmi_id) && element.xmi_id
          data[:data_type] = element.type if
            element.respond_to?(:type) && element.type
          data[:stereotype] = element.stereotype if
            element.respond_to?(:stereotype) && element.stereotype
          data[:visibility] = element.visibility if
            element.respond_to?(:visibility) && element.visibility
          data[:is_abstract] = element.is_abstract if
            element.respond_to?(:is_abstract)

          if element.attributes && !element.attributes.empty?
            data[:attributes] = element.attributes.map do |attr|
              {
                name: attr.name,
                type: attr.type,
              }
            end
          end

          if element.respond_to?(:operations) && element.operations &&
              !element.operations.empty?
            data[:operations] = element.operations.map(&:name)
          end

          data
        end
      end

      # Register with factory
      PresenterFactory.register(Lutaml::Uml::DataType, DataTypePresenter)
    end
  end
end
