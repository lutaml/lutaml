# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      autoload :ContentModelMatcher,
               "lutaml/xsd/validation/content_model_matcher"
      autoload :EngineBacked, "lutaml/xsd/validation/engine_backed"
      autoload :HintedSchemaRepository,
               "lutaml/xsd/validation/hinted_schema_repository"
      autoload :OccurrenceProductGuard,
               "lutaml/xsd/validation/occurrence_product_guard"
      autoload :SchemaLocationExtractor,
               "lutaml/xsd/validation/schema_location_extractor"
      autoload :SchemaLocationHints,
               "lutaml/xsd/validation/schema_location_hints"
      autoload :ValueSpace, "lutaml/xsd/validation/value_space"
      autoload :WildcardScope, "lutaml/xsd/validation/wildcard_scope"
      autoload :XmlBuiltins, "lutaml/xsd/validation/xml_builtins"
    end
  end
end
