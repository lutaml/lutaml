# frozen_string_literal: true

require "lutaml/uml/version"
require "lutaml/uml/parsers/dsl"
require "lutaml/uml/parsers/yaml"
require "lutaml/uml/parsers/attribute"
require "lutaml/uml/formatter"

module Lutaml
  module Uml
    class Error < StandardError; end
  end
end
