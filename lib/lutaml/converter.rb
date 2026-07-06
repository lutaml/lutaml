# frozen_string_literal: true

module Lutaml
  module Converter
    autoload :DslToUml, "lutaml/converter/dsl_to_uml"
    autoload :UmlToDsl, "lutaml/converter/uml_to_dsl"
    autoload :XmiToUmlGeneralization,
             "lutaml/converter/xmi_to_uml_generalization"
    autoload :XmiToUml, "lutaml/converter/xmi_to_uml"
  end
end
