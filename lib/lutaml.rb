# frozen_string_literal: true

require_relative "lutaml/version"
require "lutaml/lml"
require "lutaml/uml"
require "lutaml/uml_repository"

module Lutaml
  class Error < StandardError; end

  autoload :Express, "lutaml/express"
end
