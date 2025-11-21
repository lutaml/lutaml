# frozen_string_literal: true

module Lutaml
  module Ea
    module Diagram
      # Layout engine for positioning diagram elements
      #
      # This engine calculates optimal positions for diagram elements
      # based on their relationships and EA diagram data. It handles
      # automatic layout for elements that don't have explicit positions.
      class LayoutEngine
        DEFAULT_SPACING = 50
        ELEMENT_WIDTH = 120
        ELEMENT_HEIGHT = 80

        attr_reader :spacing, :element_width, :element_height

        def initialize(options = {})
          @spacing = options[:spacing] || DEFAULT_SPACING
          @element_width = options[:element_width] || ELEMENT_WIDTH
          @element_height = options[:element_height] || ELEMENT_HEIGHT
        end

        # Calculate bounds for the entire diagram
        # @param diagram_data [Hash] Diagram data with elements and connectors
        # @return [Hash] Bounds with x, y, width, height
        def calculate_bounds(diagram_data)
          elements = diagram_data[:elements] || []
          return { x: 0, y: 0, width: 400, height: 300 } if elements.empty?

          # Find min/max coordinates
          min_x = elements.map { |e| e[:x] || 0 }.min
          max_x = elements.map { |e| (e[:x] || 0) + element_width_for(e) }.max
          min_y = elements.map { |e| e[:y] || 0 }.min
          max_y = elements.map { |e| (e[:y] || 0) + element_height_for(e) }.max

          {
            x: min_x,
            y: min_y,
            width: max_x - min_x,
            height: max_y - min_y
          }
        end

        # Apply automatic layout to elements without positions
        # @param elements [Array] Array of diagram elements
        # @param connectors [Array] Array of connectors
        # @return [Array] Elements with calculated positions
        def apply_layout(elements, connectors = [])
          positioned_elements = elements.select { |e| e[:x] && e[:y] }
          unpositioned_elements = elements.reject { |e| e[:x] && e[:y] }

          # Apply force-directed layout for unpositioned elements
          if unpositioned_elements.any?
            positioned_elements += apply_force_directed_layout(
              unpositioned_elements,
              connectors,
              positioned_elements
            )
          end

          positioned_elements
        end

        # Calculate optimal position for a single element
        # @param element [Hash] Element data
        # @param related_elements [Array] Related elements
        # @return [Hash] Element with calculated position
        def calculate_element_position(element, related_elements = [])
          return element if element[:x] && element[:y]

          # Simple positioning: place to the right of related elements
          if related_elements.any?
            max_x = related_elements.map { |e| (e[:x] || 0) + element_width_for(e) }.max
            element[:x] = max_x + spacing
            element[:y] = related_elements.first[:y] || 0
          else
            element[:x] = 0
            element[:y] = 0
          end

          element
        end

        private

        def element_width_for(element)
          # Could be customized based on element content
          case element[:type]
          when "class" then element[:attributes]&.size.to_i * 10 + ELEMENT_WIDTH
          when "package" then ELEMENT_WIDTH + 20
          else ELEMENT_WIDTH
          end
        end

        def element_height_for(element)
          # Could be customized based on element content
          case element[:type]
          when "class" then element[:operations]&.size.to_i * 15 + ELEMENT_HEIGHT
          when "package" then ELEMENT_HEIGHT - 10
          else ELEMENT_HEIGHT
          end
        end

        def apply_force_directed_layout(elements, connectors, fixed_elements)
          # Simple force-directed layout implementation
          # In a real implementation, this would use iterative relaxation

          positioned = []
          elements.each_with_index do |element, index|
            # Start with a grid-like initial position
            cols = Math.sqrt(elements.size).ceil
            row = index / cols
            col = index % cols

            x = col * (ELEMENT_WIDTH + spacing)
            y = row * (ELEMENT_HEIGHT + spacing)

            # Adjust based on fixed elements
            if fixed_elements.any?
              x += fixed_elements.map { |e| (e[:x] || 0) + element_width_for(e) }.max + spacing * 2
            end

            positioned << element.merge(x: x, y: y)
          end

          positioned
        end
      end
    end
  end
end