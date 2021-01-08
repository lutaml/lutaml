# require "lutaml/express"
require "lutaml/uml"
require "lutaml/uml/lutaml_path/document_wrapper"
# require "lutaml/express/lutaml_path/document_wrapper"

module Lutaml
  module Parser
    module_function

    def parse(file)
      case File.extname(file.path)[1..-1]
      # when "exp"
      #   Lutaml::Express::LutamlPath::DocumentWrapper
      #     .new(Lutaml::Express::Parsers::Exp.parse(file))
      when "lutaml"
        Lutaml::Uml::LutamlPath::DocumentWrapper
          .new(Lutaml::Uml::Parsers::Dsl.parse(file))
      else
        raise ArgumentError, "Unsupported file format"
      end
    end
  end
end
