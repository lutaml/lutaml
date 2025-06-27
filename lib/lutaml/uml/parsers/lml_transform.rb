require "parslet"

module Lutaml
  module Uml
    module Parsers
      class LmlTransform < Parslet::Transform
        # === Base values ===
        rule(string: simple(:x))  { x.to_s }
        rule(boolean: simple(:x)) { x == "true" }
        rule(number: simple(:x))  { Integer(x) rescue x.to_s }
        rule(identifier: simple(:x)) { x.to_s }

        # === Require statement ===
        rule(require: simple(:req)) do
          { require: req.to_s }
        end

        # === Attributes ===
        rule(key: simple(:k), value: simple(:v)) do
          { k.to_sym => v }
        end

        rule(attributes: sequence(:attrs)) do
          attrs.reduce({}, :merge)
        end

        # === Lists ===
        rule(list: sequence(:items)) { items }

        # === Instances ===
        rule(
          instance_type: simple(:type),
          attributes: simple(:attrs)
        ) do
          {
            __type__: type.to_s,
            **(attrs || {})
          }
        end

        # === Root instance ===
        rule(
          name: simple(:name),
          attributes: simple(:attrs)
        ) do
          {
            name: name.to_s,
            attributes: attrs || {}
          }
        end

        # === Top-level require block ===
        rule(requires: sequence(:reqs)) do
          { requires: reqs.map { |r| r[:require] } }
        end
      end
    end
  end
end
