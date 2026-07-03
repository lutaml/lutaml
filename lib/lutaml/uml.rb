# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module Uml
    class Error < StandardError; end

    # Base modules and mixins
    autoload :HasAttributes, "lutaml/uml/has_attributes"
    autoload :HasMembers, "lutaml/uml/has_members"
    autoload :ModelHelpers, "lutaml/uml/model_helpers"
    autoload :Namespace, "lutaml/uml/namespace"
    autoload :PackagePath, "lutaml/uml/package_path"
    autoload :QualifiedName, "lutaml/uml/qualified_name"

    # Value types
    autoload :Cardinality, "lutaml/uml/cardinality"
    autoload :Fidelity, "lutaml/uml/fidelity"
    autoload :Value, "lutaml/uml/value"
    autoload :Fontname, "lutaml/uml/fontname"
    autoload :TaggedValue, "lutaml/uml/tagged_value"

    # Core elements
    autoload :TopElement, "lutaml/uml/top_element"
    autoload :TopElementAttribute, "lutaml/uml/top_element_attribute"
    autoload :GeneralAttribute, "lutaml/uml/general_attribute"

    # Relationships
    autoload :AssociationGeneralization, "lutaml/uml/association_generalization"
    autoload :Generalization, "lutaml/uml/generalization"
    autoload :Association, "lutaml/uml/association"
    autoload :Dependency, "lutaml/uml/dependency"
    autoload :Abstraction, "lutaml/uml/abstraction"
    autoload :Realization, "lutaml/uml/realization"

    # Classifiers
    autoload :Classifier, "lutaml/uml/classifier"
    autoload :Class, "lutaml/uml/class"
    autoload :DataType, "lutaml/uml/data_type"
    autoload :Enum, "lutaml/uml/enum"
    autoload :PrimitiveType, "lutaml/uml/primitive_type"
    autoload :Actor, "lutaml/uml/actor"

    # Behavioral elements
    autoload :Action, "lutaml/uml/action"
    autoload :Behavior, "lutaml/uml/behavior"
    autoload :Activity, "lutaml/uml/activity"
    autoload :OpaqueBehavior, "lutaml/uml/opaque_behavior"

    # State machine elements
    autoload :Vertex, "lutaml/uml/vertex"
    autoload :State, "lutaml/uml/state"
    autoload :FinalState, "lutaml/uml/final_state"
    autoload :Pseudostate, "lutaml/uml/pseudostate"
    autoload :Region, "lutaml/uml/region"
    autoload :StateMachine, "lutaml/uml/state_machine"
    autoload :Transition, "lutaml/uml/transition"
    autoload :Event, "lutaml/uml/event"
    autoload :Trigger, "lutaml/uml/trigger"

    # Structural elements
    autoload :Property, "lutaml/uml/property"
    autoload :Port, "lutaml/uml/port"
    autoload :Operation, "lutaml/uml/operation"
    autoload :OperationParameter, "lutaml/uml/operation_parameter"
    autoload :Constraint, "lutaml/uml/constraint"

    # Composite elements
    autoload :Connector, "lutaml/uml/connector"
    autoload :ConnectorEnd, "lutaml/uml/connector_end"
    autoload :Group, "lutaml/uml/group"
    autoload :Package, "lutaml/uml/package"
    autoload :Model, "lutaml/uml/model"

    # Documentation
    autoload :Comment, "lutaml/uml/comment"
    autoload :Diagram, "lutaml/uml/diagram"
    autoload :DiagramObject, "lutaml/uml/diagram_object"
    autoload :DiagramLink, "lutaml/uml/diagram_link"
    autoload :Instance, "lutaml/uml/instance"
    autoload :Document, "lutaml/uml/document"

    # Node (DSL AST nodes)
    module Node
      autoload :Base, "lutaml/uml/node/base"
      autoload :HasName, "lutaml/uml/node/has_name"
      autoload :HasType, "lutaml/uml/node/has_type"
      autoload :Attribute, "lutaml/uml/node/attribute"
      autoload :ClassNode, "lutaml/uml/node/class_node"
      autoload :ClassRelationship, "lutaml/uml/node/class_relationship"
      autoload :Document, "lutaml/uml/node/document"
      autoload :MethodArgument, "lutaml/uml/node/method_argument"
      autoload :Operation, "lutaml/uml/node/operation"
      autoload :Relationship, "lutaml/uml/node/relationship"
    end

    # Parsers
    module Parsers
      autoload :Dsl, "lutaml/uml/parsers/dsl"
      autoload :DslPreprocessor, "lutaml/uml/parsers/dsl_preprocessor"
      autoload :DslTransform, "lutaml/uml/parsers/dsl_transform"
      autoload :Yaml, "lutaml/uml/parsers/yaml"
      autoload :Attribute, "lutaml/uml/parsers/attribute"
    end

    # Validation
    module Validation
      autoload :DocumentStructureValidator,
               "lutaml/uml/validation/document_structure_validator"
    end
  end
end
