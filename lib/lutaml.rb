# frozen_string_literal: true

require_relative "lutaml/version"
require "lutaml/model"
# The LutaML Model Language core (namespace, models, formatter/layout
# seam registries) ships inside lutaml-model from 0.8.188; this gem no
# longer carries lib/lutaml/lml. The render backends (ELK, DOT
# emission, SVG/PDF) live in lutaml-diagram, which reopens
# Lutaml::Formatter and Lutaml::Layout.
require "lutaml/lml"

# The serialization runtime is the lutaml-model gem. lutaml-uml loads when
# present (it depends on lutaml-model, not on this gem).
%w[lutaml/uml lutaml/uml_repository].each do |feature|
  require feature
rescue LoadError => e
  raise unless e.path == feature
end

module Lutaml
  class Error < StandardError; end
end
