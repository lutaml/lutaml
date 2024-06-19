# frozen_string_literal: true

require "yaml"
require "lutaml/uml/class"
require "lutaml/uml/document"
require "lutaml/uml/serializers/yaml_view"

module Lutaml
  module Uml
    module Parsers
      class Yaml
        def self.parse(yaml_path, options = {})
          new.parse(yaml_path, options)
        end

        def parse(yaml_path, _options = {})
          yaml_parse(yaml_path)
        end

        def yaml_parse(yaml_path)
          yaml_content = YAML.safe_load(File.read(yaml_path))
          serialized_yaml = Lutaml::Uml::Serializers::YamlView
            .new(yaml_content)
          result = Lutaml::Uml::Document.new(serialized_yaml)
          result.classes = imports_to_classes(yaml_content, yaml_path)
          result
        end

        private

        def imports_to_classes(yaml_content, yaml_path)
          models_path = File.join(File.dirname(yaml_path), "..", "models")
          yaml_content["imports"].map do |(klass_name, _)|
            klass_attrs = YAML.safe_load(
              File.read(
                File.join(models_path, "#{klass_name}.yml")
              )
            )
            klass_attrs["name"] = klass_name if klass_attrs["name"].nil?
            Lutaml::Uml::Serializers::Class.new(klass_attrs)
          end
        end
      end
    end
  end
end
