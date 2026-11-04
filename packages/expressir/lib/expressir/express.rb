# frozen_string_literal: true

module Expressir
  module Express
    autoload :AstKeyConverter, "#{__dir__}/express/ast_key_converter"
    autoload :Builder, "#{__dir__}/express/builder"
    autoload :BuilderContext, "#{__dir__}/express/builder_context"
    autoload :BuilderRegistry, "#{__dir__}/express/builder_registry"
    autoload :Builders, "#{__dir__}/express/builders"

    # Core classes (autoloaded for lazy loading)
    autoload :Cache, "#{__dir__}/express/cache"
    autoload :AdocHyperlinkFormatter, "#{__dir__}/express/adoc_hyperlink_formatter"
    autoload :AdocSourceFormatter, "#{__dir__}/express/adoc_source_formatter"
    autoload :Checker, "#{__dir__}/express/checker"
    autoload :Concatenator, "#{__dir__}/express/concatenator"
    autoload :Core, "#{__dir__}/express/core"
    autoload :Dialect, "#{__dir__}/express/dialect"
    autoload :RemarkOverlay, "#{__dir__}/express/remark_overlay"
    autoload :ModelTraversal, "#{__dir__}/express/model_traversal"
    autoload :RefsOverlay, "#{__dir__}/express/refs_overlay"
    autoload :Error, "#{__dir__}/express/error"
    autoload :Formatter, "#{__dir__}/express/formatter"
    autoload :Formatters, "#{__dir__}/express/formatters"
    autoload :Grammar, "#{__dir__}/express/grammar"
    autoload :HyperlinkFormatter, "#{__dir__}/express/hyperlink_formatter"
    autoload :InterfaceDot, "#{__dir__}/express/interface_dot"
    autoload :LineMap, "#{__dir__}/express/line_map"
    autoload :Listing, "#{__dir__}/express/listing"
    autoload :ModelVisitor, "#{__dir__}/express/model_visitor"
    autoload :NodePositionIndex, "#{__dir__}/express/node_position_index"
    autoload :ParallelFiles, "#{__dir__}/express/parallel_files"
    autoload :Parser, "#{__dir__}/express/parser"
    autoload :PrettyFormatter, "#{__dir__}/express/pretty_formatter"
    autoload :PrettyGate, "#{__dir__}/express/pretty_gate"
    autoload :RemarkAttacher, "#{__dir__}/express/remark_attacher"
    autoload :RemarkScanner, "#{__dir__}/express/remark_scanner"
    autoload :ResolveReferencesModelVisitor,
             "#{__dir__}/express/resolve_references_model_visitor"
    autoload :SelfSchemaReference, "#{__dir__}/express/self_schema_reference"
    autoload :Shtolo, "#{__dir__}/express/shtolo"
    autoload :SchemaBlockScanner, "#{__dir__}/express/schema_block_scanner"
    autoload :SchemaHeadFormatter, "#{__dir__}/express/schema_head_formatter"
    autoload :SchemaPlainSourceFormatter,
             "#{__dir__}/express/schema_plain_source_formatter"
    autoload :SchemaSourceFormatter, "#{__dir__}/express/schema_source_formatter"
    autoload :SchemaCompare, "#{__dir__}/express/schema_compare"
    autoload :SchemaPatch, "#{__dir__}/express/schema_compare"
    autoload :ChangeClassification,
             "#{__dir__}/express/change_classification"
    autoload :ScopeResolver, "#{__dir__}/express/scope_resolver"
    autoload :LazyRepository, "#{__dir__}/express/lazy_repository"
    autoload :SmrlXml, "#{__dir__}/express/smrl_xml"
    autoload :Xsd, "#{__dir__}/express/xsd"
    autoload :SourceFormatter, "#{__dir__}/express/source_formatter"
    autoload :StreamingBuilder, "#{__dir__}/express/streaming_builder"
  end
end
