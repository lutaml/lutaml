# frozen_string_literal: true

require_relative "lutaml/version"
require_relative "lutaml/lml"
require "lutaml/model"

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
