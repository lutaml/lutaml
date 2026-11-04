# frozen_string_literal: true

require "cgi"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Utils
          # Helper methods for building SVG elements
          class SvgBuilder
            def self.escape_xml(text)
              CGI.escape_html(text.to_s)
            end

            def self.element(name, attributes = {}, content = nil)
              attr_str = attributes.map do |k, v|
                "#{k}=\"#{escape_xml(v)}\""
              end.join(" ")

              if content
                "<#{name} #{attr_str}>#{content}</#{name}>"
              elsif block_given?
                "<#{name} #{attr_str}>#{yield}</#{name}>"
              else
                "<#{name} #{attr_str}/>"
              end
            end

            def self.rect(x, y, width, height, attributes = {})
              element("rect", attributes.merge(
                                x: x, y: y, width: width, height: height,
                              ))
            end

            def self.circle(cx, cy, r, attributes = {})
              element("circle", attributes.merge(cx: cx, cy: cy, r: r))
            end

            def self.line(x1, y1, x2, y2, attributes = {})
              element("line", attributes.merge(
                                x1: x1, y1: y1, x2: x2, y2: y2,
                              ))
            end

            def self.text(x, y, content, attributes = {})
              element("text", attributes.merge(x: x, y: y), escape_xml(content))
            end

            def self.group(attributes = {}, &)
              element("g", attributes, &)
            end

            def self.polygon(points, attributes = {})
              points_str = points.map { |p| "#{p.x},#{p.y}" }.join(" ")
              element("polygon", attributes.merge(points: points_str))
            end

            def self.path(d, attributes = {})
              element("path", attributes.merge(d: d))
            end
          end
        end
      end
    end
  end
end
