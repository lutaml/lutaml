# frozen_string_literal: true

require "liquid"
require "lutaml/path"

module Lutaml
  module Xmi
    # Parsers
    module Parsers
      autoload :Xml, "lutaml/xmi/parsers/xml"
      autoload :XmiBase, "lutaml/xmi/parsers/xmi_base"
    end

    # Liquid drops for template rendering
    module LiquidDrops
      autoload :RootDrop, "lutaml/xmi/liquid_drops/root_drop"
      autoload :PackageDrop, "lutaml/xmi/liquid_drops/package_drop"
      autoload :KlassDrop, "lutaml/xmi/liquid_drops/klass_drop"
      autoload :AttributeDrop, "lutaml/xmi/liquid_drops/attribute_drop"
      autoload :OperationDrop, "lutaml/xmi/liquid_drops/operation_drop"
      autoload :AssociationDrop, "lutaml/xmi/liquid_drops/association_drop"
      autoload :GeneralizationDrop,
               "lutaml/xmi/liquid_drops/generalization_drop"
      autoload :GeneralizationAttributeDrop,
               "lutaml/xmi/liquid_drops/generalization_attribute_drop"
      autoload :DependencyDrop, "lutaml/xmi/liquid_drops/dependency_drop"
      autoload :ConstraintDrop, "lutaml/xmi/liquid_drops/constraint_drop"
      autoload :DiagramDrop, "lutaml/xmi/liquid_drops/diagram_drop"
      autoload :EnumDrop, "lutaml/xmi/liquid_drops/enum_drop"
      autoload :EnumOwnedLiteralDrop,
               "lutaml/xmi/liquid_drops/enum_owned_literal_drop"
      autoload :DataTypeDrop, "lutaml/xmi/liquid_drops/data_type_drop"
      autoload :CardinalityDrop, "lutaml/xmi/liquid_drops/cardinality_drop"
      autoload :ConnectorDrop, "lutaml/xmi/liquid_drops/connector_drop"
      autoload :SourceTargetDrop, "lutaml/xmi/liquid_drops/source_target_drop"
    end
  end
end
