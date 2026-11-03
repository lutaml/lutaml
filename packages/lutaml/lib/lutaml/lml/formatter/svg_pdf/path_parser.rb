# frozen_string_literal: true

module Lutaml
  module Formatter
    class SvgPdf
      # Minimal SVG path data parser: absolute and relative M/m, L/l,
      # H/h, V/v, C/c, Z/z — enough for ELK geometry and arrow shapes.
      class PathParser
        Point = Struct.new(:x, :y)
        Line = Struct.new(:point) do
          def last_point
            point
          end
        end
        Curve = Struct.new(:c1, :c2, :point) do
          def last_point
            point
          end
        end
        Close = Struct.new(:last_point)

        attr_reader :subpaths

        def initialize(d, dx, dy)
          @dx = dx
          @dy = dy
          parse(d)
        end

        private

        def parse(d)
          tokens = d.scan(/[MmLlHhVvCcZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?/)
          current = Point.new(0.0, 0.0)
          start = current
          @subpaths = [[]]
          i = 0
          while i < tokens.size
            cmd = tokens[i]
            i += 1
            case cmd
            when 'Z', 'z'
              @subpaths.last << Close.new(start)
              current = start.dup
            when 'M', 'm'
              current, start = move_to(tokens, i, current, cmd == 'm')
              i += 2
              @subpaths << [] if cmd == 'm'
            when 'L', 'l'
              current = line_to(tokens, i, current, cmd == 'l')
              i += 2
            when 'H', 'h'
              current = h_line(tokens, i, current, cmd == 'h')
              i += 1
            when 'V', 'v'
              current = v_line(tokens, i, current, cmd == 'v')
              i += 1
            when 'C', 'c'
              current = curve_to(tokens, i, current, cmd == 'c')
              i += 6
            end
          end
          finish
        end

        def move_to(tokens, i, current, relative)
          x = num(tokens, i)
          y = num(tokens, i + 1)
          point = relative ? Point.new(current.x + x, current.y + y) : Point.new(x, y)
          [point, point.dup]
        end

        def line_to(tokens, i, current, relative)
          x = num(tokens, i)
          y = num(tokens, i + 1)
          point = relative ? Point.new(current.x + x, current.y + y) : Point.new(x, y)
          @subpaths.last << Line.new(point.dup)
          point
        end

        def h_line(tokens, i, current, relative)
          x = num(tokens, i) + (relative ? current.x : 0)
          point = Point.new(x, current.y)
          @subpaths.last << Line.new(point.dup)
          point
        end

        def v_line(tokens, i, current, relative)
          y = num(tokens, i) + (relative ? current.y : 0)
          point = Point.new(current.x, y)
          @subpaths.last << Line.new(point.dup)
          point
        end

        def curve_to(tokens, i, current, relative)
          c1 = Point.new(num(tokens, i), num(tokens, i + 1))
          c2 = Point.new(num(tokens, i + 2), num(tokens, i + 3))
          to = Point.new(num(tokens, i + 4), num(tokens, i + 5))
          if relative
            c1 = Point.new(c1.x + current.x, c1.y + current.y)
            c2 = Point.new(c2.x + current.x, c2.y + current.y)
            to = Point.new(to.x + current.x, to.y + current.y)
          end
          @subpaths.last << Curve.new(c1, c2, to)
          to
        end

        def num(tokens, i)
          tokens[i].to_f
        end

        def finish
          @subpaths.map { |segments| segments.map { |s| offset(s) } }
                   .reject(&:empty?)
        end

        def offset(segment)
          case segment
          when Line
            Line.new(shift(segment.point))
          when Curve
            Curve.new(shift(segment.c1), shift(segment.c2), shift(segment.point))
          else
            segment
          end
        end

        def shift(point)
          Point.new(point.x + @dx, point.y + @dy)
        end
      end
    end
  end
end
