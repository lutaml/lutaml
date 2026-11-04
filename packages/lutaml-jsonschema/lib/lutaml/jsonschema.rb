# frozen_string_literal: true

require "lutaml/model"
require "lutaml/store"

module Lutaml
  module Jsonschema
    class Error < StandardError; end

    autoload :VERSION, "lutaml/jsonschema/version"
    autoload :Dialect, "lutaml/jsonschema/dialect"
    autoload :Validator, "lutaml/jsonschema/validator"
    autoload :Base, "lutaml/jsonschema/base"
    autoload :Link, "lutaml/jsonschema/link"
    autoload :PropertyEntry, "lutaml/jsonschema/property_entry"
    autoload :TupleItem, "lutaml/jsonschema/tuple_item"
    autoload :Schema, "lutaml/jsonschema/schema"
    autoload :ReferenceResolver, "lutaml/jsonschema/reference_resolver"
    autoload :SourceFile, "lutaml/jsonschema/source_file"
    autoload :SchemaSet, "lutaml/jsonschema/schema_set"
    autoload :SchemaStore, "lutaml/jsonschema/schema_store"
    autoload :Combiner, "lutaml/jsonschema/combiner"
    autoload :Diff, "lutaml/jsonschema/diff"
    autoload :Configuration, "lutaml/jsonschema/configuration"
    autoload :LjrPackageDefinition, "lutaml/jsonschema/ljr_package_definition"
    autoload :Cli, "lutaml/jsonschema/cli"

    module Exports
      autoload :Cddl, "lutaml/jsonschema/exports/cddl"
      autoload :Adoc, "lutaml/jsonschema/exports/adoc"
      autoload :Openapi, "lutaml/jsonschema/exports/openapi"
      autoload :Xsd, "lutaml/jsonschema/exports/xsd"
      autoload :Lml, "lutaml/jsonschema/exports/lml"
    end

    module Spa
      autoload :Metadata, "lutaml/jsonschema/spa/metadata"
      autoload :SpaProperty, "lutaml/jsonschema/spa/spa_property"
      autoload :SpaDefinition, "lutaml/jsonschema/spa/spa_definition"
      autoload :SpaSchema, "lutaml/jsonschema/spa/spa_schema"
      autoload :SpaSearchEntry, "lutaml/jsonschema/spa/spa_search_entry"
      autoload :SpaDiffEntry, "lutaml/jsonschema/spa/spa_diff_entry"
      autoload :SpaLink, "lutaml/jsonschema/spa/spa_link"
      autoload :SpaBuilder, "lutaml/jsonschema/spa/spa_builder"
      autoload :SpaDocument, "lutaml/jsonschema/spa/spa_document"
      autoload :OutputStrategy, "lutaml/jsonschema/spa/output_strategy"
      autoload :VueInlinedStrategy, "lutaml/jsonschema/spa/vue_inlined_strategy"
      autoload :Generator, "lutaml/jsonschema/spa/generator"
    end
  end
end
