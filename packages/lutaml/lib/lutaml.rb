# frozen_string_literal: true

require_relative "lutaml/version"
require_relative "lutaml/lml"
require_relative "lutaml/model"

# lutaml-uml depends on the model runtime (this gem), so this gem cannot
# depend on it back without a cycle bundler rejects (#233). The UML models
# load when the lutaml-uml gem is in the bundle.
%w[lutaml/uml lutaml/uml_repository].each do |feature|
  require feature
rescue LoadError => e
  raise unless e.path == feature
end

module Lutaml
  class Error < StandardError; end
end
