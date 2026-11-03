# frozen_string_literal: true

module Expressir
  module Model
    module Declarations
      autoload :Attribute, "#{__dir__}/declarations/attribute"
      autoload :Constant, "#{__dir__}/declarations/constant"
      autoload :DerivedAttribute, "#{__dir__}/declarations/derived_attribute"
      autoload :Entity, "#{__dir__}/declarations/entity"
      autoload :Function, "#{__dir__}/declarations/function"
      autoload :Interface, "#{__dir__}/declarations/interface"
      autoload :InterfaceItem, "#{__dir__}/declarations/interface_item"
      autoload :InterfacedItem, "#{__dir__}/declarations/interfaced_item"
      autoload :InverseAttribute, "#{__dir__}/declarations/inverse_attribute"
      autoload :Parameter, "#{__dir__}/declarations/parameter"
      autoload :Procedure, "#{__dir__}/declarations/procedure"
      autoload :RemarkItem, "#{__dir__}/declarations/remark_item"
      autoload :Rule, "#{__dir__}/declarations/rule"
      autoload :Schema, "#{__dir__}/declarations/schema"
      autoload :SchemaVersion, "#{__dir__}/declarations/schema_version"
      autoload :SchemaVersionItem, "#{__dir__}/declarations/schema_version_item"
      autoload :SubtypeConstraint, "#{__dir__}/declarations/subtype_constraint"
      autoload :Type, "#{__dir__}/declarations/type"
      autoload :UniqueRule, "#{__dir__}/declarations/unique_rule"
      autoload :Variable, "#{__dir__}/declarations/variable"
      autoload :WhereRule, "#{__dir__}/declarations/where_rule"
      autoload :InformalPropositionRule,
               "#{__dir__}/declarations/informal_proposition_rule"
    end
  end
end
