# frozen_string_literal: true

require_relative "util"

module Lutaml
  module Ea
    module Diagram
      # Path builder for connector rendering
      #
      # This class calculates SVG path data for connectors between
      # diagram elements, supporting various connector types and
      # routing algorithms.
      class PathBuilder
        include Util

        attr_reader :connector, :source_element, :target_element

        def initialize(connector, source_element = nil, target_element = nil)
          @connector = connector
          @source_element = source_element
          @target_element = target_element
        end

        # Build SVG path data for the connector
        # @return [String] SVG path data
        def build_path
          return straight_path if simple_connector?

          case connector[:routing_type]
          when "orthogonal" then orthogonal_path
          when "bezier" then bezier_path
          else manhattan_path
          end
        end

        private

        def simple_connector?
          # Use straight line if both elements have direct coordinates
          connector[:source_x] && connector[:source_y] &&
          connector[:target_x] && connector[:target_y]
        end

        def straight_path
          x1 = connector[:source_x] || 0
          y1 = connector[:source_y] || 0
          x2 = connector[:target_x] || 100
          y2 = connector[:target_y] || 100

          "M #{x1},#{y1} L #{x2},#{y2}"
        end

        def orthogonal_path
          # Right-angle routing
          points = calculate_orthogonal_points
          path_from_points(points)
        end

        def manhattan_path
          # Manhattan distance routing with one bend
          x1, y1 = source_point
          x2, y2 = target_point

          # Calculate bend point (midpoint)
          bend_x = (x1 + x2) / 2
          bend_y = (y1 + y2) / 2

          # Choose bend direction to avoid elements
          if (x2 - x1).abs > (y2 - y1).abs
            # Horizontal bend
            "M #{x1},#{y1} L #{bend_x},#{y1} L #{bend_x},#{y2} L #{x2},#{y2}"
          else
            # Vertical bend
            "M #{x1},#{y1} L #{x1},#{bend_y} L #{x2},#{bend_y} L #{x2},#{y2}"
          end
        end

        def bezier_path
          # Smooth curved path using Bezier curves
          x1, y1 = source_point
          x2, y2 = target_point

          # Control points for smooth curve
          cp1x = x1 + (x2 - x1) * 0.3
          cp1y = y1
          cp2x = x2 - (x2 - x1) * 0.3
          cp2y = y2

          "M #{x1},#{y1} C #{cp1x},#{cp1y} #{cp2x},#{cp2y} #{x2},#{y2}"
        end

        def calculate_orthogonal_points
          x1, y1 = source_point
          x2, y2 = target_point

          points = [[x1, y1]]

          # Determine direction based on relative positions
          if (x2 - x1).abs > (y2 - y1).abs
            # Horizontal first, then vertical
            points << [x1 + (x2 - x1) / 2, y1]
            points << [x1 + (x2 - x1) / 2, y2]
          else
            # Vertical first, then horizontal
            points << [x1, y1 + (y2 - y1) / 2]
            points << [x2, y1 + (y2 - y1) / 2]
          end

          points << [x2, y2]
          points
        end

        def path_from_points(points)
          return "" if points.empty?

          path = "M #{points[0][0]},#{points[0][1]}"
          points[1..].each do |point|
            path += " L #{point[0]},#{point[1]}"
          end
          path
        end

        def source_point
          if connector[:source_x] && connector[:source_y]
            [connector[:source_x], connector[:source_y]]
          else
            calculate_element_connection_point(source_element, :source)
          end
        end

        def target_point
          if connector[:target_x] && connector[:target_y]
            [connector[:target_x], connector[:target_y]]
          else
            calculate_element_connection_point(target_element, :target)
          end
        end

        def calculate_element_connection_point(element, type)
          return [0, 0] unless element

          # Calculate connection point based on element bounds and 
          # connector type
          x = element[:x] || 0
          y = element[:y] || 0
          width = element[:width] || 120
          height = element[:height] || 80

          point = case type
                  when :source
                    # Connect from right side for outgoing connectors
                    [x + width, y + height / 2]
                  when :target
                    # Connect to left side for incoming connectors
                    [x, y + height / 2]
                  else
                    [x + width / 2, y + height / 2]
                  end

          return point unless connector[:geometry]

          # Apply relative offsets if specified
          offsets = parse_geometry_offsets(connector[:geometry])
          apply_offset(point, offsets, type)
        end

        def apply_offset(point, offsets, type)
          offset_x, offset_y = case type
                               when :source
                                 [offsets[0], offsets[1]]
                               when :target
                                 [offsets[2], offsets[3]]
                               else
                                 [0, 0] 
                               end

          [point[0] + offset_x, point[1] + offset_y]
        end

        def start_point
          return nil unless source_element

          calculate_element_center_point(source_element)
        end

        def end_point
          return nil unless target_element

          calculate_element_center_point(target_element)
        end

        def calculate_element_center_point(element)
          # Calculate center point based on element bounds
          x = element[:x] || 0
          y = element[:y] || 0
          width = element[:width] || 120
          height = element[:height] || 80

          [x + width / 2, y + height / 2]
        end

        def calculate_start_end_point(geometry_data, type)
          point = if type == :source
                    start_point
                  else
                    end_point
                  end

          if point.nil? || !geometry_data[:has_relative_coords]
            return nil
          end

          offsets = [
            geometry_data[:source_offset_x] || 0,
            geometry_data[:source_offset_y] || 0,
            geometry_data[:target_offset_x] || 0,
            geometry_data[:target_offset_y] || 0
          ]
          
          apply_offset(point, offsets, type)
        end

        def calculate_start_point(geometry_data)
          calculate_start_end_point(geometry_data, :source)
        end

        def calculate_end_point(geometry_data)
          calculate_start_end_point(geometry_data, :target)
        end
      end
    end
  end
end