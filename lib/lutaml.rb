# frozen_string_literal: true

require_relative "lutaml/version"
require "lutaml/uml"
require "lutaml/uml_repository"
require "lutaml/converter"
require "lutaml/ea"
require "lutaml/xmi"
require "lutaml/qea"
require "lutaml/formatter"
require "lutaml/layout"
require "lutaml/model_transformations"
require "lutaml/cli"

module Lutaml
  class Error < StandardError; end

  autoload :Express, "lutaml/express"
end
