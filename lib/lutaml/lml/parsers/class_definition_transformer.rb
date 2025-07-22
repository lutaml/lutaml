require "parslet"

require_relative "class_definition"
require_relative "../nodes"

module Lutaml
  module Lml
    module Parsers
      class ClassDefinitionTransform < Parslet::Transform
        # === Basic value transformations ===
        rule(string: simple(:x)) { x.to_s }
        rule(name: simple(:x)) { x.to_s }
        rule(boolean: simple(:x)) { x.to_s == "true" }
        rule(number: simple(:x)) { x.to_s.to_i }
        rule(identifier: simple(:x)) { x.to_s }
        rule(start: simple(:x), end: simple(:y)) { x.to_s..y.to_s }
        rule(range: simple(:x)) { x }
        rule(variable: simple(:x)) { x.to_s }
        rule(require: simple(:x)) { x.to_s }
        rule(reference: sequence(:x)) { x.join(".") }
        rule(list: sequence(:x)) { x }
        rule(instance: simple(:instance)) { instance }

        rule(comment: simple(:x)) do
          Lutaml::Lml::Nodes::Comment.new(text: x.to_s)
        end

        rule(requires: sequence(:requires), instance: simple(:instance)) do
          instance.requires = requires
          instance
        end

        rule(key: simple(:name), value: simple(:value)) do
          Lutaml::Lml::Nodes::Property.new(
            name: name.to_s,
            value: value,
          )
        end

        rule(key: simple(:name), value: sequence(:value)) do
          Lutaml::Lml::Nodes::Property.new(
            name: name.to_s,
            value: value,
          )
        end

        rule(name: simple(:name), attributes: sequence(:properties)) do
          Lutaml::Lml::Nodes::AttributeDefinition.new(
            name: name.to_s,
            properties: properties,
          )
        end

        rule(
          name: simple(:name),
          attribute_definitions: sequence(:attribute_definitions),
        ) do
          Lutaml::Lml::Nodes::ClassDefinition.new(
            name: name.to_s,
            attribute_definitions: attribute_definitions,
          )
        end

        rule(
          name: simple(:name),
          parent_class: simple(:parent_class),
          attributes: sequence(:attributes),
        ) do
          Lutaml::Lml::Nodes::ClassDefinition.new(
            name: name.to_s,
            parent_class: parent_class.to_s,
            attribute_definitions: attributes,
          )
        end

        rule(
          requires: sequence(:requires),
          name: simple(:name),
          classes: sequence(:classes),
        ) do
          Lutaml::Lml::Nodes::Model.new(
            requires: requires,
            name: name.to_s,
            class_definitions: classes,
          )
        end

        rule(
          instance_type: simple(:instance_type),
          attributes: sequence(:attributes),
        ) do
          Lutaml::Lml::Nodes::Instance.new(
            type: instance_type.to_s,
            attributes: attributes,
          )
        end
      end
    end
  end
end
