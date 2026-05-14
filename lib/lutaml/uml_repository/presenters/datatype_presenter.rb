# frozen_string_literal: true

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
          if element.xmi_id
            lines << "XMI ID:        #{element.xmi_id}"
          end
          if element.type
            lines << "Type:          #{element.type}"
          end
          if element.stereotype && !element.stereotype.empty?
            lines << "Stereotype:    #{element.stereotype}"
          end
          if element.visibility
            lines << "Visibility:    #{element.visibility}"
          end
          lines << "Abstract:      #{element.is_abstract}"
          lines << ""

          if element.attributes && !element.attributes.empty?
            lines << "Attributes (#{element.attributes.size}):"
            element.attributes.each do |attr|
              type_info = attr.type ? " : #{attr.type}" : ""
              lines << "  - #{attr.name}#{type_info}"
            end
            lines << ""
          end

          if element.operations && !element.operations.empty?
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

          data[:xmi_id] = element.xmi_id if element.xmi_id
          data[:data_type] = element.type if element.type
          data[:stereotype] = element.stereotype if
            element.stereotype && !element.stereotype.empty?
          data[:visibility] = element.visibility if element.visibility
          data[:is_abstract] = element.is_abstract

          if element.attributes && !element.attributes.empty?
            data[:attributes] = element.attributes.map do |attr|
              {
                name: attr.name,
                type: attr.type,
              }
            end
          end

          if element.operations && !element.operations.empty?
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
