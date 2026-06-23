# frozen_string_literal: true

module Lutaml
  # Schema realization: generate XSD / JSON Schema from a UML
  # {Lutaml::Uml::Document} by synthesizing lutaml-model Serializable classes
  # and bridging to lutaml-model's emitters. Which attribute becomes an XML
  # attribute vs element, and element ordering, are decided by an
  # {Lutaml::Schema::EncodingRule} reading generic tagged values on the model
  # (so the same model can target different schema languages).
  module Schema
    autoload :Bridge, "lutaml/schema/bridge"
    autoload :EncodingRule, "lutaml/schema/encoding_rule"
  end
end
