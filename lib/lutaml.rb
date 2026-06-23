# frozen_string_literal: true

require_relative "lutaml/version"

module Lutaml
  class Error < StandardError; end

  autoload :Express, "lutaml/express"
  autoload :Formatter, "lutaml/formatter"
  autoload :Layout, "lutaml/layout"
  autoload :Uml, "lutaml/uml"
  autoload :UmlRepository, "lutaml/uml_repository"
  autoload :Xmi, "lutaml/xmi"
  autoload :Ea, "lutaml/ea"
  autoload :Qea, "lutaml/qea"
  autoload :Converter, "lutaml/converter"
  autoload :ModelTransformations, "lutaml/model_transformations"
  autoload :Schema, "lutaml/schema"
end
