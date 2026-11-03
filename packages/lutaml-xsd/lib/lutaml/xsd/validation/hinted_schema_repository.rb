# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # HintedSchemaRepository layers instance-hinted schemas over an
      # inner repository: hinted declarations validate alongside the
      # package's own, and hinted documents compile from their source
      # files so the engine resolves their relative imports.
      class HintedSchemaRepository
        # Parse the hinted paths and build the layered repository; nil
        # when no hint resolves (the inner repository stands alone).
        #
        # @param inner [#all_schemas, #source_path_for] the package repository
        # @param xml_content [String] the instance document
        # @param base_dir [String] directory the hints resolve from
        # @return [HintedSchemaRepository, nil]
        def self.from_hints(inner, xml_content, base_dir)
          locations = SchemaLocationHints.paths(xml_content, base_dir)
          return nil if locations.empty?

          schemas = {}
          hinted_locations = {}
          locations.each do |path|
            schema = Lutaml::Xml::Schema::Xsd.parse(File.read(path),
                                                    location: path)
            key = schema.target_namespace if
              schema.target_namespace.to_s.match?(/\S/)
            schemas[key] = schema
            hinted_locations[path] = schema
          rescue StandardError
            # A hint the tree cannot satisfy contributes nothing.
            next
          end
          return nil if schemas.empty?

          new(inner, schemas, hinted_locations)
        end

        # @param inner [#all_schemas] the package repository
        # @param schemas [Hash] namespace => hinted Schema
        # @param locations [Hash] source path => hinted Schema
        def initialize(inner, schemas, locations)
          @inner = inner
          @schemas = schemas
          @locations = locations
        end

        def all_schemas
          inner_all = @inner.all_schemas.dup
          @schemas.each do |key, schema|
            inner_all[key] = schema unless inner_all.key?(key)
          end
          inner_all
        end

        # @return [String, nil] the file the schema was parsed from
        def source_path_for(schema)
          @locations.find { |_path, candidate| candidate.equal?(schema) }
            &.first || @inner.source_path_for(schema)
        rescue NoMethodError
          nil
        end
      end
    end
  end
end
