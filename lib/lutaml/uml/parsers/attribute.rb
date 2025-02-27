# frozen_string_literal: true

require "parslet"

module Lutaml
  module Uml
    module Parsers
      class Attribute < Parslet::Parser
        class Transform < Parslet::Transform
          rule(integer: simple(:x)) { Integer(x) }
          rule(float: simple(:x)) { Float(x) }
          rule(string: simple(:x)) { String(x) }
        end

        def self.parse(io, options = {})
          new.parse(io, options)
        end

        def parse(io, options = {})
          tree = Transform.new.apply(super)
          tree[:assignments].each_with_object({}) do |assignment, memo|
            memo[assignment[:name].to_s] = assignment[:value]
          end
        end

        rule(:spaces) { match("\s").repeat(1) }
        rule(:spaces?) { spaces.maybe }

        rule(:digits) { match["0-9"].repeat(1) }

        rule(:integer) do
          (str("-").maybe >> digits >> str(".").absent?).as(:integer)
        end
        rule(:float) do
          (str("-").maybe >> digits >> str(".") >> digits).as(:float)
        end

        rule(:string_single_quoted) do
          str("'") >>
            (str("'").absent? >> any).repeat.as(:string) >>
            str("'")
        end
        rule(:string_double_quoted) do
          str('"') >>
            (str('"').absent? >> any).repeat.as(:string) >>
            str('"')
        end

        rule(:string) { string_single_quoted | string_double_quoted }

        rule(:assignment_name) do
          (match["=\s"].absent? >> any).repeat.as(:name)
        end
        rule(:assignment_value) { (integer | float | string).as(:value) }
        rule(:assignment) do
          assignment_name >> spaces? >> str("=") >> spaces? >> assignment_value
        end

        rule(:attribute) { spaces? >> assignment >> spaces? }
        rule(:attributes) do
          (attribute >> (str(",") >> attribute).repeat).repeat.as(:assignments)
        end

        root(:attributes)
      end
    end
  end
end
