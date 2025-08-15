# frozen_string_literal: true

require "lutaml/model"

require "lutaml/uml/has_attributes"
require "lutaml/uml/has_members"
require "lutaml/uml/namespace"
require "lutaml/uml/cardinality"
require "lutaml/uml/fidelity"
require "lutaml/uml/top_element"
require "lutaml/uml/top_element_attribute"
require "lutaml/uml/value"
require "lutaml/uml/action"
require "lutaml/uml/classifier"
require "lutaml/uml/dependency"
require "lutaml/uml/association"
require "lutaml/uml/constraint"
require "lutaml/uml/operation"
require "lutaml/uml/class"
require "lutaml/uml/data_type"
require "lutaml/uml/enum"
require "lutaml/uml/diagram"
require "lutaml/uml/package"
require "lutaml/uml/primitive_type"
require "lutaml/uml/group"
require "lutaml/uml/connector"
require "lutaml/uml/connector_end"
require "lutaml/uml/behavior"
require "lutaml/uml/activity"
require "lutaml/uml/vertex"
require "lutaml/uml/state"
require "lutaml/uml/final_state"
require "lutaml/uml/property"
require "lutaml/uml/port"
require "lutaml/uml/document"

require "lutaml/uml/parsers/dsl"
require "lutaml/uml/parsers/yaml"
require "lutaml/uml/parsers/attribute"
require "lutaml/formatter"
require "lutaml/formatter/graphviz"

Dir.glob(File.expand_path("./uml/**/*.rb", __dir__)).sort.each do |file|
  require file
end

module Lutaml
  module Uml
    class Error < StandardError; end
  end
end
