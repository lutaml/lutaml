# frozen_string_literal: true

# Compatibility shim for Schema class moved to lutaml-model
# This file provides backward compatibility for code that references
# Lutaml::Xsd::Schema (which was the old location before XSD parsing
# was moved to lutaml-model)
#
# @deprecated Use Lutaml::Xml::Schema::Xsd::Schema directly instead
module Lutaml
  module Xsd
    # Alias for the Schema class now located in lutaml-model
    # This is provided for backward compatibility with existing
    # serialized packages that reference Lutaml::Xsd::Schema
    Schema = Lutaml::Xml::Schema::Xsd::Schema
  end
end
