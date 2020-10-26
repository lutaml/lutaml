require "lutaml/express"

module Lutaml
  module Parser
    module_function

    def parse(file)
      case File.extname(file.path)[1..-1]
      when "exp"
        Lutaml::Express::LutamlPath::DocumentWrapper
          .new(Lutaml::Express::Parsers::Exp.parse(file))
      else
        raise ArgumentError, 'Unsupported file format'
      end
    end
  end
end