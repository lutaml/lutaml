# frozen_string_literal: true

require "lutaml"

document = Lutaml::Lml.parse("diagram City { class Building {} }")
formatter = Lutaml::Formatter::Graphviz.new
formatter.type = :svg
svg = formatter.format(document)
raise "Graphviz did not return SVG" unless svg.include?("<svg")

File.write(ARGV.fetch(0, "city.svg"), svg)
