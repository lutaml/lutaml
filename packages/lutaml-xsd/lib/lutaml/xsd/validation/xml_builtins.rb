# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Declarations for the reserved xml namespace built-ins
      # (http://www.w3.org/XML/1998/namespace). Schemas reference them
      # without defining them — `xs:attribute ref="xml:base"` — so the
      # resolver synthesizes them (XSD 1.0 §3.2.6 builds them in).
      module XmlBuiltins
        NAMESPACE = "http://www.w3.org/XML/1998/namespace"

        TYPES = {
          "base" => "xs:anyURI",
          "lang" => "xs:language",
          "space" => "xs:string",
          "id" => "xs:ID",
        }.freeze

        module_function

        # @param local [String] base, lang, space or id
        # @return [Lutaml::Xml::Schema::Xsd::Attribute, nil]
        def attribute(local)
          type = TYPES[local]
          return nil unless type

          @declarations ||= {}
          @declarations[local] ||=
            Lutaml::Xml::Schema::Xsd::Attribute.new(name: local, type: type)
        end
      end
    end
  end
end
