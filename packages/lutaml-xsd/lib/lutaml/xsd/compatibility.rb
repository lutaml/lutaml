# frozen_string_literal: true

# Compatibility aliases for XSD element classes moved to lutaml-model
#
# This module provides backward compatibility for code that references
# Lutaml::Xsd::* classes (which were the old XSD element classes
# before XSD parsing was moved to lutaml-model as Lutaml::Xml::Schema::Xsd::*)
#
# @deprecated These aliases exist only for backward compatibility with
#   existing serialized packages. New code should use Lutaml::Xml::Schema::Xsd::*
#   classes directly.

module Lutaml
  module Xsd
    # Aliases for XSD element classes now in lutaml-model
    # These allow old serialized packages to be loaded

    # Schema structure classes
    Element = Lutaml::Xml::Schema::Xsd::Element
    Attribute = Lutaml::Xml::Schema::Xsd::Attribute
    ComplexType = Lutaml::Xml::Schema::Xsd::ComplexType
    SimpleType = Lutaml::Xml::Schema::Xsd::SimpleType
    Sequence = Lutaml::Xml::Schema::Xsd::Sequence
    Choice = Lutaml::Xml::Schema::Xsd::Choice
    All = Lutaml::Xml::Schema::Xsd::All
    Group = Lutaml::Xml::Schema::Xsd::Group

    # Content model classes
    ComplexContent = Lutaml::Xml::Schema::Xsd::ComplexContent
    SimpleContent = Lutaml::Xml::Schema::Xsd::SimpleContent

    # Extension and restriction classes
    ExtensionComplexContent = Lutaml::Xml::Schema::Xsd::ExtensionComplexContent
    ExtensionSimpleContent = Lutaml::Xml::Schema::Xsd::ExtensionSimpleContent
    RestrictionComplexContent = Lutaml::Xml::Schema::Xsd::RestrictionComplexContent
    RestrictionSimpleContent = Lutaml::Xml::Schema::Xsd::RestrictionSimpleContent
    RestrictionSimpleType = Lutaml::Xml::Schema::Xsd::RestrictionSimpleType

    # Schema includes and imports
    Include = Lutaml::Xml::Schema::Xsd::Include
    Import = Lutaml::Xml::Schema::Xsd::Import
    Redefine = Lutaml::Xml::Schema::Xsd::Redefine

    # Annotation classes
    Annotation = Lutaml::Xml::Schema::Xsd::Annotation
    Documentation = Lutaml::Xml::Schema::Xsd::Documentation
    Appinfo = Lutaml::Xml::Schema::Xsd::Appinfo

    # Constraint classes
    Unique = Lutaml::Xml::Schema::Xsd::Unique
    Key = Lutaml::Xml::Schema::Xsd::Key
    Keyref = Lutaml::Xml::Schema::Xsd::Keyref
    Selector = Lutaml::Xml::Schema::Xsd::Selector
    Field = Lutaml::Xml::Schema::Xsd::Field

    # Wildcards
    Any = Lutaml::Xml::Schema::Xsd::Any
    AnyAttribute = Lutaml::Xml::Schema::Xsd::AnyAttribute

    # Attribute group
    AttributeGroup = Lutaml::Xml::Schema::Xsd::AttributeGroup

    # Notation
    Notation = Lutaml::Xml::Schema::Xsd::Notation

    # Simple type facets
    Length = Lutaml::Xml::Schema::Xsd::Length
    MinLength = Lutaml::Xml::Schema::Xsd::MinLength
    MaxLength = Lutaml::Xml::Schema::Xsd::MaxLength
    Pattern = Lutaml::Xml::Schema::Xsd::Pattern
    Enumeration = Lutaml::Xml::Schema::Xsd::Enumeration
    WhiteSpace = Lutaml::Xml::Schema::Xsd::WhiteSpace
    MaxInclusive = Lutaml::Xml::Schema::Xsd::MaxInclusive
    MaxExclusive = Lutaml::Xml::Schema::Xsd::MaxExclusive
    MinInclusive = Lutaml::Xml::Schema::Xsd::MinInclusive
    MinExclusive = Lutaml::Xml::Schema::Xsd::MinExclusive
    TotalDigits = Lutaml::Xml::Schema::Xsd::TotalDigits
    FractionDigits = Lutaml::Xml::Schema::Xsd::FractionDigits

    # List and union types
    List = Lutaml::Xml::Schema::Xsd::List
    Union = Lutaml::Xml::Schema::Xsd::Union
  end
end
