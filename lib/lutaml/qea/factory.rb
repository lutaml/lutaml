# frozen_string_literal: true

module Lutaml
  module Qea
    module Factory
      autoload :BaseTransformer, "lutaml/qea/factory/base_transformer"
      autoload :AssociationBuilder, "lutaml/qea/factory/association_builder"
      autoload :AssociationTransformer,
               "lutaml/qea/factory/association_transformer"
      autoload :AttributeTagTransformer,
               "lutaml/qea/factory/attribute_tag_transformer"
      autoload :AttributeTransformer, "lutaml/qea/factory/attribute_transformer"
      autoload :ClassTransformer, "lutaml/qea/factory/class_transformer"
      autoload :ConstraintTransformer,
               "lutaml/qea/factory/constraint_transformer"
      autoload :DataTypeTransformer, "lutaml/qea/factory/data_type_transformer"
      autoload :DiagramTransformer, "lutaml/qea/factory/diagram_transformer"
      autoload :DocumentBuilder, "lutaml/qea/factory/document_builder"
      autoload :EnumTransformer, "lutaml/qea/factory/enum_transformer"
      autoload :GeneralizationBuilder,
               "lutaml/qea/factory/generalization_builder"
      autoload :GeneralizationTransformer,
               "lutaml/qea/factory/generalization_transformer"
      autoload :InstanceTransformer, "lutaml/qea/factory/instance_transformer"
      autoload :ObjectPropertyTransformer,
               "lutaml/qea/factory/object_property_transformer"
      autoload :OperationTransformer, "lutaml/qea/factory/operation_transformer"
      autoload :PackageTransformer, "lutaml/qea/factory/package_transformer"
      autoload :ReferenceResolver, "lutaml/qea/factory/reference_resolver"
      autoload :StereotypeLoader, "lutaml/qea/factory/stereotype_loader"
      autoload :TaggedValueTransformer,
               "lutaml/qea/factory/tagged_value_transformer"
      autoload :TransformerRegistry, "lutaml/qea/factory/transformer_registry"
      autoload :EaToUmlFactory, "lutaml/qea/factory/ea_to_uml_factory"
    end
  end
end
