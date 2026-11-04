# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for component rendering rules
          class ComponentRules
            def initialize(components_hash)
              @components = components_hash
            end

            def rule_for(component_type)
              ComponentRule.new(@components[component_type.to_s] || {})
            end

            def element
              rule_for("element")
            end

            def type
              rule_for("type")
            end

            def attribute
              rule_for("attribute")
            end

            def group
              rule_for("group")
            end
          end

          # Individual component rule value object
          class ComponentRule
            attr_reader :icon, :filter

            def initialize(rule_hash)
              @icon = rule_hash["icon"]
              @show_cardinality = rule_hash["show_cardinality"] || false
              @show_namespace = rule_hash["show_namespace"] || false
              @show_type = rule_hash["show_type"] || false
              @show_default = rule_hash["show_default"] || false
              @show_base_type = rule_hash["show_base_type"] || false
              @show_derivation = rule_hash["show_derivation"] || false
              @clickable = rule_hash["clickable"] || false
              @filter = rule_hash["filter"]
            end

            def show_cardinality?
              @show_cardinality
            end

            def show_namespace?
              @show_namespace
            end

            def show_type?
              @show_type
            end

            def show_default?
              @show_default
            end

            def show_base_type?
              @show_base_type
            end

            def show_derivation?
              @show_derivation
            end

            def clickable?
              @clickable
            end
          end
        end
      end
    end
  end
end
