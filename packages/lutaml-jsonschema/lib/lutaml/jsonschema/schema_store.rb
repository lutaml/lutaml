# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # SchemaStore extends SchemaSet with on-disk persistence via lutaml-store.
    #
    # Inherited from SchemaSet (zero duplication):
    #   resolve_ref, validate!, valid?, validation_errors,
    #   all_definitions, all_properties, collect_refs
    #
    # Added by SchemaStore:
    #   load_from_directory, save_to_directory, configuration access,
    #   remove_schema, convenience query methods
    class SchemaStore < SchemaSet
      attr_reader :package

      def initialize(package: nil, **)
        super(**)
        @package = package || Lutaml::Store::PackageStore.new(LjrPackageDefinition.definition)
      end

      # ── Class-level loaders ──

      def self.load_from_directory(dir, format: nil)
        pkg = Lutaml::Store::PackageStore.load(
          LjrPackageDefinition.definition, dir,
          transport: :directory, format: format
        )
        store = new(package: pkg)
        store.sync_from_package
        store
      end

      def self.load_from_files(*paths, base_dir: nil, **)
        store = new(**)
        paths.each do |path|
          schema, source = SourceFile.load(path)
          name = File.basename(path, ".*")
          schema.dollar_id ||= name
          store.add(name, schema, path, source)
        end
        store.base_dir = base_dir if base_dir
        store
      end

      # ── Overrides ──

      def add(name, schema, file_path = nil, source_json = nil)
        super
        @package.add_model(schema)
      end

      # ── Convenience accessors ──

      def schema(name)
        @schemas[name]
      end

      def schema_names
        @schemas.keys
      end

      def schema_count
        @schemas.size
      end

      def schema_exists?(name)
        @schemas.key?(name)
      end

      def add_schema(schema, file_path = nil, source_json = nil)
        name = schema.dollar_id || (if file_path
                                      File.basename(file_path,
                                                    ".*")
                                    end)
        unless name
          raise Error,
                "Schema must have $id or file_path for name derivation"
        end

        schema.dollar_id ||= name
        add(name, schema, file_path, source_json)
      end

      def remove_schema(name)
        s = @schemas.delete(name)
        @package.remove_model(Schema, s.dollar_id) if s&.dollar_id
      end

      # ── Configuration ──

      def configuration
        @package.models_for(Configuration).first
      end

      def configuration=(config)
        existing = configuration
        @package.remove_model(Configuration, existing.title) if existing&.title
        @package.add_model(config)
      end

      # ── Persistence ──

      def save_to_directory(path, format: nil, formats: {})
        @package.save(path, transport: :directory, format: format,
                            formats: formats)
      end

      # ── Sync ──

      def sync_from_package
        @package.models_for(Schema).each do |s|
          next unless s.dollar_id

          name = File.basename(s.dollar_id).sub(/\..*/, "")
          name = disambiguate(name) if @schemas.key?(name)
          @schemas[name] = s
        end
      end

      private

      def disambiguate(name)
        return name unless @schemas.key?(name)

        counter = 2
        loop do
          candidate = "#{name}_#{counter}"
          return candidate unless @schemas.key?(candidate)

          counter += 1
        end
      end
    end
  end
end
