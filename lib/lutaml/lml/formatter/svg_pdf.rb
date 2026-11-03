# frozen_string_literal: true

module Lutaml
  module Formatter
    # SVG-to-PDF renderer for ELK-layout diagrams (issue #53). Parses the
    # ELK SVG output and re-emits it through pdfrb's Canvas: base-14
    # standard fonts for text (metrics ship inside pdfrb, no external
    # font resources), stroke/fill operators for shapes, and arrow
    # markers drawn manually at polyline ends (SVG marker geometry is
    # resolved from the document's <defs> and inlined with rotation).
    class SvgPdf
      autoload :PathParser, 'lutaml/lml/formatter/svg_pdf/path_parser'

      FONT_VARIANTS = {
        'Helvetica' => { bold: :Helvetica_Bold, normal: :Helvetica },
        'Courier' => { bold: :Courier_Bold, normal: :Courier },
        'Times' => { bold: :Times_Bold, normal: :Times_Roman }
      }.freeze
      ROUNDING = 0.5523

      def initialize(svg)
        @svg = svg
      end

      def render
        require 'pdfrb'
        doc = Pdfrb::Document.new
        page = doc.pages.add
        @canvas = page.canvas
        root = Moxml.parse(@svg).root
        @width, @height = page_dimensions(root)
        @canvas.line_width = 1
        @markers = {}
        @marker_parents = {}
        collect_markers(root, nil)
        walk(root, 0.0, 0.0)
        io = StringIO.new
        doc.write(io: io)
        io.string.b
      end

      private

      def page_dimensions(root)
        [float_attr(root, 'width', 612.0), float_attr(root, 'height', 792.0)]
      end

      def float_attr(node, name, fallback)
        node.attribute(name)&.value&.to_f || fallback
      end

      def collect_markers(node, _parent)
        node.children.each do |child|
          if child.name == 'marker'
            shape = child.children.find { |c| %w[path polygon polyline].include?(c.name) }
            if shape
              @markers[child.attribute('id')&.value] = shape
              @marker_parents[shape] = child
            end
          end
          collect_markers(child, node)
        end
      end

      # Depth-first walk applying cumulative translate(x,y).
      def walk(node, dx, dy)
        node.children.each do |child|
          # Whitespace between elements arrives as text nodes under
          # some moxml adapters; only elements carry geometry.
          next unless child.element?

          cdx, cdy = translate_of(child)
          case child.name
          when 'g'
            walk(child, dx + cdx, dy + cdy)
          when 'rect'
            draw_rect(child, dx + cdx, dy + cdy)
          when 'polyline'
            draw_polyline(child, dx, dy)
          when 'polygon'
            draw_polygon(child, dx, dy)
          when 'line'
            draw_line(child, dx, dy)
          when 'path'
            draw_path(child, dx + cdx, dy + cdy)
          when 'text'
            draw_text(child, dx + cdx, dy + cdy)
          end
        end
      end

      def translate_of(node)
        t = node.attribute('transform')&.value.to_s
        m = t.match(/translate\(\s*([-\d.]+)[,\s]+([-\d.]+)\s*\)/)
        m ? [m[1].to_f, m[2].to_f] : [0.0, 0.0]
      end

      # SVG user space is y-down; PDF is y-up.
      def pt(x, y)
        [x, @height - y]
      end

      def draw_rect(node, dx, dy)
        x = float_attr(node, 'x', 0.0) + dx
        y = float_attr(node, 'y', 0.0) + dy
        w = float_attr(node, 'width', 0.0)
        h = float_attr(node, 'height', 0.0)
        rx = float_attr(node, 'rx', 0.0)
        set_fill(node)
        set_stroke(node)
        if rx.positive?
          rounded_path(x, y, w, h, rx)
        else
          @canvas.rectangle(*pt(x, y), w, h)
        end
        paint(node)
      end

      def rounded_path(x, y, w, h, r)
        r = [r, w / 2.0, h / 2.0].min
        k = ROUNDING * r
        _, y2 = pt(x + w, y + h)
        top_left, = pt(x, y)
        @canvas.move_to(*pt(x + r, y))
        @canvas.line_to(*pt(x + w - r, y))
        @canvas.curve_to(x + w - r + k, y, x + w, y + r - k, x + w, y + r)
        @canvas.line_to(x + w, y + h - r)
        @canvas.curve_to(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y2)
        @canvas.line_to(x + r, y2)
        @canvas.curve_to(x + r - k, y + h, x, y + h - r + k, x, y + h - r)
        @canvas.line_to(x, y + r)
        @canvas.curve_to(x, y + r - k, x + r - k, y, x + r, top_left)
      end

      def draw_polyline(node, dx, dy)
        points = point_list(node, dx, dy)
        return if points.empty?

        set_stroke(node)
        @canvas.line_width = float_attr(node, 'stroke-width', 1.0)
        @canvas.polyline(points.map { |x, y| pt(x, y) })
        @canvas.stroke
        draw_marker(node, points)
      end

      def draw_polygon(node, dx, dy)
        points = point_list(node, dx, dy)
        return if points.empty?

        set_fill(node)
        set_stroke(node)
        @canvas.polygon(points.map { |x, y| pt(x, y) })
        paint(node)
      end

      def draw_line(node, dx, dy)
        x1 = float_attr(node, 'x1', 0.0) + dx
        y1 = float_attr(node, 'y1', 0.0) + dy
        x2 = float_attr(node, 'x2', 0.0) + dx
        y2 = float_attr(node, 'y2', 0.0) + dy
        set_stroke(node)
        @canvas.line(*pt(x1, y1), *pt(x2, y2))
      end

      def point_list(node, dx, dy)
        node.attribute('points')&.value.to_s.scan(/(-?[\d.]+)[,\s]+(-?[\d.]+)/)
            .map { |x, y| [x.to_f + dx, y.to_f + dy] }
      end

      def draw_path(node, dx, dy)
        subpaths = PathParser.new(node.attribute('d')&.value.to_s, dx, dy).subpaths
        set_fill(node)
        set_stroke(node)
        subpaths.each do |segments|
          first = segments.first
          next unless first

          @canvas.move_to(*pt(*first.last_point))
          segments.each do |segment|
            case segment
            when PathParser::Line
              @canvas.line_to(*pt(*segment.point))
            when PathParser::Curve
              c1 = pt(*segment.c1)
              c2 = pt(*segment.c2)
              to = pt(*segment.point)
              @canvas.curve_to(*c1, *c2, *to)
            when PathParser::Close
              @canvas.close_path
            end
          end
          paint(node)
        end
      end

      def draw_marker(node, points)
        ref = node.attribute('marker-end')&.value.to_s[/url\(#([^)]+)\)/, 1]
        shape = @markers[ref]
        return unless shape && points.size >= 2

        (x1, y1), (x2, y2) = points[-2, 2]
        angle = Math.atan2(y2 - y1, x2 - x1)
        cos = Math.cos(angle)
        sin = Math.sin(angle)
        marker = @marker_parents[shape]
        ref_x = float_attr(marker, 'refX', 0.0)
        ref_y = float_attr(marker, 'refY', 0.0)
        set_fill(shape)
        set_stroke(shape)
        trace_marker(shape, x2, y2, cos, sin, ref_x, ref_y)
        paint(shape)
      end

      # Trace the marker's shape geometry translated to (x2,y2) with the
      # marker origin at (refX,refY), rotated by the edge direction.
      def trace_marker(shape, ox, oy, cos, sin, ref_x, ref_y)
        transform = lambda { |x, y|
          lx = x - ref_x
          ly = y - ref_y
          [ox + lx * cos - ly * sin, oy + lx * sin + ly * cos]
        }
        d = shape.name == 'path' ? shape.attribute('d')&.value.to_s : nil
        segments = d ? PathParser.new(d, 0.0, 0.0).subpaths.first : nil
        return unless segments&.any?

        first = segments.first.last_point
        @canvas.move_to(*pt(*transform.call(*first)))
        segments.each do |segment|
          case segment
          when PathParser::Line
            @canvas.line_to(*pt(*transform.call(*segment.point)))
          when PathParser::Curve
            @canvas.curve_to(*pt(*transform.call(*segment.c1)),
                             *pt(*transform.call(*segment.c2)),
                             *pt(*transform.call(*segment.point)))
          when PathParser::Close
            @canvas.close_path
          end
        end
      end

      def draw_text(node, dx, dy)
        x = float_attr(node, 'x', 0.0) + dx
        y = float_attr(node, 'y', 0.0) + dy
        size = float_attr(node, 'font-size', 12.0)
        @canvas.text(node.text.to_s, at: pt(x, y),
                                     font: font_for(node), size: size)
      end

      def font_for(node)
        family = node.attribute('font-family')&.value.to_s
        base = FONT_VARIANTS.keys.find { |k| family.include?(k) } || 'Helvetica'
        bold = node.attribute('font-weight')&.value.to_s =~ /bold/i
        FONT_VARIANTS[base][bold ? :bold : :normal]
      end

      def set_fill(node)
        @fill_color = color_attr(node, 'fill')
        @canvas.fill_color(@fill_color) if @fill_color
      end

      def set_stroke(node)
        @stroke_color = color_attr(node, 'stroke')
        @canvas.stroke_color(@stroke_color) if @stroke_color
      end

      def paint(node)
        fill = color_attr(node, 'fill')
        stroke = color_attr(node, 'stroke')
        if fill && fill != 'none' && stroke && stroke != 'none'
          @canvas.fill_stroke
        elsif fill && fill != 'none'
          @canvas.fill
        else
          @canvas.stroke
        end
      end

      def color_attr(node, name)
        value = node.attribute(name)&.value.to_s
        value =~ /\A#/ ? value : nil
      end
    end
  end
end
