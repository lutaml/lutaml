# frozen_string_literal: true

require "yaml"
require "lutaml/uml"

module Lutaml
  module Uml
    module Parsers
      class Yaml
        def self.parse(yaml_path, options = {})
          new.parse(yaml_path, options)
        end

        def parse(yaml_path, _options = {})
          Lutaml::Uml::Document.from_yaml(File.read(yaml_path))
        end
      end
    end
  end
end
