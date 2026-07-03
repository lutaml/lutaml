# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Qea
    module Models
      autoload :BaseModel, "lutaml/qea/models/base_model"
      autoload :EaAttribute, "lutaml/qea/models/ea_attribute"
      autoload :EaAttributeTag, "lutaml/qea/models/ea_attribute_tag"
      autoload :EaComplexityType, "lutaml/qea/models/ea_complexity_type"
      autoload :EaConnector, "lutaml/qea/models/ea_connector"
      autoload :EaConnectorType, "lutaml/qea/models/ea_connector_type"
      autoload :EaConstraintType, "lutaml/qea/models/ea_constraint_type"
      autoload :EaDatatype, "lutaml/qea/models/ea_datatype"
      autoload :EaDiagram, "lutaml/qea/models/ea_diagram"
      autoload :EaDiagramLink, "lutaml/qea/models/ea_diagram_link"
      autoload :EaDiagramObject, "lutaml/qea/models/ea_diagram_object"
      autoload :EaDiagramType, "lutaml/qea/models/ea_diagram_type"
      autoload :EaDocument, "lutaml/qea/models/ea_document"
      autoload :EaObject, "lutaml/qea/models/ea_object"
      autoload :EaObjectConstraint, "lutaml/qea/models/ea_object_constraint"
      autoload :EaObjectProperty, "lutaml/qea/models/ea_object_property"
      autoload :EaObjectType, "lutaml/qea/models/ea_object_type"
      autoload :EaOperation, "lutaml/qea/models/ea_operation"
      autoload :EaOperationParam, "lutaml/qea/models/ea_operation_param"
      autoload :EaPackage, "lutaml/qea/models/ea_package"
      autoload :EaScript, "lutaml/qea/models/ea_script"
      autoload :EaStatusType, "lutaml/qea/models/ea_status_type"
      autoload :EaStereotype, "lutaml/qea/models/ea_stereotype"
      autoload :EaTaggedValue, "lutaml/qea/models/ea_tagged_value"
      autoload :EaXref, "lutaml/qea/models/ea_xref"
    end
  end
end
