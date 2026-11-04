# frozen_string_literal: true

require "lutaml/model"
require "lutaml/xml/schema/xsd"

module Lutaml
  module Xsd
    # Error class for lutaml-xsd specific errors
    class Error < StandardError; end
  end
end

require_relative "xsd/version"
require_relative "xsd/errors"
require_relative "xsd/file_validation_result"
require_relative "xsd/validation_error"
require_relative "xsd/namespace_uri_remapping"
require_relative "xsd/base_package_config"
require_relative "xsd/package_source"
require_relative "xsd/conflicts/namespace_conflict"
require_relative "xsd/conflicts/type_conflict"
require_relative "xsd/conflicts/schema_conflict"
require_relative "xsd/package_conflict_detector"
require_relative "xsd/package_conflict_resolver"
require_relative "xsd/conflict_report"
require_relative "xsd/validation_result"
require_relative "xsd/schema_location_mapping"
require_relative "xsd/namespace_mapping"
require_relative "xsd/type_resolution_result"
require_relative "xsd/type_index_entry"
require_relative "xsd/serialized_schema"
require_relative "xsd/package_configuration"
require_relative "xsd/schema_resolver"
require_relative "xsd/xsd_bundler"
require_relative "xsd/package_builder"
require_relative "xsd/schema_name_resolver"
require_relative "xsd/schema_repository_metadata"
require_relative "xsd/schema_repository_package"
require_relative "xsd/rng_to_xsd_converter"
require_relative "xsd/schema_repository"
require_relative "xsd/compatibility"
require_relative "xsd/xsd_model_extensions"
require_relative "xsd/schema"
require_relative "xsd/schema_classifier"
require_relative "xsd/package_validator"
require_relative "xsd/package_tree_formatter"
require_relative "xsd/type_searcher"
require_relative "xsd/batch_type_query"
require_relative "xsd/validation"
require_relative "xsd/validation/validator"
require_relative "xsd/spa"
require_relative "xsd/interactive_builder"
require_relative "xsd/coverage_analyzer"
require_relative "xsd/definition_extractor"
require_relative "xsd/dependency_grapher"
require_relative "xsd/entrypoint_identifier"
require_relative "xsd/namespace_prefix_manager"
require_relative "xsd/namespace_remapper"
require_relative "xsd/schema_file_validation_results"
require_relative "xsd/schema_dependency_analyzer"
require_relative "xsd/type_hierarchy_analyzer"
require_relative "xsd/xsd_spec_validator"
require_relative "xsd/cli"

module Lutaml
  module Xsd
    # Public parsing entry point, as documented across docs/*.adoc.
    # Delegates to lutaml-model's XML Schema parser.
    #
    # @param xsd [String] XSD content
    # @param location [String, nil] base location for import/include paths
    # @return [Lutaml::Xml::Schema::Xsd::Schema]
    def self.parse(xsd, **)
      Xml::Schema::Xsd.parse(xsd, **)
    end
  end
end
