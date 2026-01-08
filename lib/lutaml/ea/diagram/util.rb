# frozen_string_literal: true

module Lutaml
  module Ea
    module Diagram
      module Util
        # Parse geometry offsets
        def parse_geometry_offsets(geometry_string)
          begin
            geometry = parse_ea_geometry(geometry_string)

            [
              geometry[:source_offset_x]&.to_i || 0,
              geometry[:source_offset_y]&.to_i || 0,
              geometry[:target_offset_x]&.to_i || 0,
              geometry[:target_offset_y]&.to_i || 0
            ]
          rescue
            # handles malformed geometry gracefully
            [0, 0, 0, 0]
          end
        end

        def parse_ea_geometry(geometry_string)
          return nil if geometry_string.nil? || geometry_string.strip.empty?

          data = {}
          begin
            geometry = geometry_string
                        .gsub(/\s/, "")
                        .downcase
                        .split(";")
                        .map { |pair| pair.split("=") }.to_h

            geometry.each do |k, v|
              if v.include?(",")
                # waypoints
                data[:waypoints] ||= []
                x_str, y_str = v.split(",")
                data[:waypoints] << {x: x_str.to_i, y: y_str.to_i}
              else
                key = case k
                      when "sx"
                        data[:has_relative_coords] ||= true
                        "source_offset_x"
                      when "sy"
                        data[:has_relative_coords] ||= true
                        "source_offset_y"
                      when "ex"
                        data[:has_relative_coords] ||= true
                        "target_offset_x"
                      when "ey"
                        data[:has_relative_coords] ||= true
                        "target_offset_y"
                      else
                        k
                      end

                data[key.to_sym] = v&.to_i || 0
              end
            end
          rescue
            # handles malformed geometry gracefully
            data = {}
          end
          data
        end
      end
    end
  end
end
