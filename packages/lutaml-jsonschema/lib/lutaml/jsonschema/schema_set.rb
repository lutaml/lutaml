# frozen_string_literal: true

module Lutaml
  module Jsonschema
    class SchemaSet
      attr_accessor :base_dir
      attr_reader :schemas, :remote_errors

      # Network access is opt-in; a disk cache lets air-gapped runs reuse
      # previously fetched documents.
      DEFAULT_REMOTE_LOADER = lambda do |uri|
        require "net/http"

        Net::HTTP.get(URI(uri))
      end

      def initialize(base_dir: nil, allow_remote: false,
                     remote_cache_dir: nil, remote_loader: nil)
        @schemas = {}
        @base_dir = base_dir
        @file_paths = {}
        @source_jsons = {}
        @resolver = ReferenceResolver.new(@schemas)
        @allow_remote = allow_remote
        @remote_cache_dir = remote_cache_dir
        @remote_loader = remote_loader
        @remote_documents = {}
        @remote_errors = {}
      end

      def self.load_from_files(*paths, base_dir: nil, allow_remote: false,
                               remote_cache_dir: nil, remote_loader: nil)
        set = new(base_dir: base_dir || infer_base_dir(paths),
                  allow_remote: allow_remote,
                  remote_cache_dir: remote_cache_dir,
                  remote_loader: remote_loader)
        paths.each do |path|
          schema, source = SourceFile.load(path)
          name = File.basename(path, ".*")
          set.add(name, schema, path, source)
        end
        set
      end

      def self.load_from_directory(dir, **)
        paths = Dir.glob(File.join(dir, SourceFile::DIRECTORY_GLOB))
        load_from_files(*paths, base_dir: dir, **)
      end

      def add(name, schema, file_path = nil, source_json = nil)
        @schemas[name] = schema
        return unless file_path

        @file_paths[File.basename(file_path)] = file_path
        @source_jsons[name] = source_json if source_json
      end

      def source_json(name)
        @source_jsons[name]
      end

      def resolve_ref(ref_string, context_schema = nil)
        return nil unless ref_string

        if ref_string.start_with?("./")
          resolve_file_ref(ref_string, context_schema)
        elsif ref_string.start_with?("http://", "https://")
          resolve_remote_ref(ref_string)
        elsif ref_string.start_with?("#/")
          @resolver.resolve(ref_string, context_schema)
        elsif ref_string.start_with?("#") && !ref_string.start_with?("#/")
          resolve_anchor_ref(ref_string.delete_prefix("#"), context_schema)
        else
          @resolver.resolve(ref_string, context_schema)
        end
      end

      def validate!
        errors = validation_errors
        raise ValidationError, errors.join("\n") if errors.any?

        true
      end

      def valid?
        validate!
      rescue StandardError
        false
      end

      def all_definitions
        @schemas.flat_map do |_name, schema|
          schema.definition_entries
        end
      end

      def all_properties
        @schemas.flat_map do |_name, schema|
          schema.property_entries
        end
      end

      def validation_errors
        errors = []
        @schemas.each do |name, schema|
          collect_refs(schema, name, errors, Set.new, "")
        end
        errors
      end

      # Bundle mode: every schema's definitions hoisted into one
      # combined document with localized refs.
      def bundle
        combined = Schema.new

        @schemas.each do |name, schema|
          combined.definition_entries.concat(schema.definition_entries)
          combined.property_entries.push(
            PropertyEntry.new(
              name: name,
              schema: Schema.new(dollar_ref: "#/definitions/#{name}"),
            ),
          )
          combined.title ||= schema.title if schema.title
        end

        rewrite_bundled_refs!(combined)
        combined
      end

      # Dereference mode: a plain-Hash view of a named schema with
      # internal `#/...` references replaced by their targets in place.
      #
      # - Cycles are left as `$ref` nodes (path-local seen set), so the
      #   walk always terminates.
      # - External refs (`./file.json`, absolute URLs) and unresolvable
      #   refs are left untouched.
      # - Sibling keywords next to `$ref` are dropped, matching
      #   draft-04..07 reference semantics.
      def dereference(name)
        schema = @schemas.fetch(name)
        dereference_node(Yeptris::JSON.load(schema.to_json), schema, {})
      end

      private

      # The bundle renames `definitions` to `$defs`; point every local
      # `#/definitions/...` ref at the new location.
      def rewrite_bundled_refs!(schema)
        @resolver.each_schema(schema) do |node|
          ref = node.dollar_ref
          next unless ref&.start_with?("#/definitions/")

          node.dollar_ref = ref.sub(%r{^#/definitions/}, "#/$defs/")
        end
      end

      def remote_schema(base)
        @remote_documents[base] ||= begin
          document = fetch_remote_document(base)
          document && register_remote(base, document)
        end
      end

      def register_remote(base, document)
        name = remote_name(base)
        return @schemas[name] if @schemas[name]

        schema = Schema.from_json(document)
        add(name, schema)
        schema
      end

      def fetch_remote_document(uri)
        cache_path = remote_cache_path(uri)
        return File.read(cache_path) if cache_path && File.exist?(cache_path)

        unless @allow_remote
          @remote_errors[uri] = "remote refs disabled (pass allow_remote " \
                                "or provide a remote cache)"
          return nil
        end

        document = (@remote_loader || DEFAULT_REMOTE_LOADER).call(uri)
        if cache_path
          require "fileutils"

          FileUtils.mkdir_p(@remote_cache_dir)
          File.write(cache_path, document)
        end
        document
      rescue StandardError => e
        @remote_errors[uri] = e.message
        nil
      end

      def remote_cache_path(uri)
        return nil unless @remote_cache_dir

        require "digest"

        File.join(@remote_cache_dir, "#{Digest::SHA256.hexdigest(uri)}.json")
      end

      def remote_name(uri)
        base = uri.split("#", 2).first
        File.basename(URI.parse(base).path, ".*").then do |name|
          name.empty? ? URI.parse(base).host : name
        end
      end

      def dereference_node(node, context_schema, seen)
        case node
        when Array
          node.map { |item| dereference_node(item, context_schema, seen) }
        when Hash
          dereference_hash(node, context_schema, seen)
        else
          node
        end
      end

      def dereference_hash(node, context_schema, seen)
        ref = node["$ref"]
        return map_hash_values(node, context_schema, seen) unless
          ref.is_a?(String) && ref.start_with?("#/") && !seen[ref]

        target = resolve_ref(ref, context_schema)
        return map_hash_values(node, context_schema, seen) if target.nil?

        resolved = Yeptris::JSON.load(target.to_json)
        dereference_node(resolved, context_schema, seen.merge(ref => true))
      end

      def map_hash_values(node, context_schema, seen)
        node.to_h do |key, value|
          [key,
           dereference_node(value, context_schema, seen)]
        end
      end

      def self.infer_base_dir(paths)
        return nil if paths.empty?

        File.dirname(paths.first)
      end

      def resolve_file_ref(ref, context_schema)
        return nil unless context_schema

        target_file = ref.sub(%r{^\./}, "")
        schema = find_schema_by_filename(target_file)
        return schema if schema

        # Try loading from base_dir
        if @base_dir
          path = File.join(@base_dir, target_file)
          if File.exist?(path)
            loaded, = SourceFile.load(path)
            add(File.basename(target_file, ".*"), loaded, path)
            return loaded
          end
        end

        nil
      end

      # Remote documents: network access only when `allow_remote`; the
      # disk cache is consulted first so air-gapped runs reuse previously
      # fetched documents. Fragments (`uri#/definitions/x` or `uri#anchor`)
      # resolve inside the fetched document.
      def resolve_remote_ref(ref)
        base, fragment = ref.split("#", 2)
        document = remote_schema(base)
        return nil if document.nil?

        return document if fragment.nil? || fragment.empty?

        @resolver.resolve("##{fragment}", document)
      end

      def resolve_anchor_ref(anchor, context_schema)
        return nil unless context_schema

        find_anchor(context_schema, anchor)
      end

      def find_anchor(schema, anchor)
        return schema if schema.dollar_anchor == anchor

        schema.each_child do |child, _segment|
          found = find_anchor(child, anchor)
          return found if found
        end

        nil
      end

      def find_schema_by_filename(filename)
        @schemas.each do |name, schema|
          return schema if name == File.basename(filename, ".*")
        end

        return nil unless @file_paths.key?(filename)

        name = File.basename(filename, ".*")
        @schemas[name]
      end

      def collect_refs(schema, source_name, errors, seen_refs, path)
        ref = schema.dollar_ref
        if ref && !seen_refs.include?("#{source_name}:#{path}:#{ref}")
          seen_refs.add("#{source_name}:#{path}:#{ref}")
          resolved = resolve_ref(ref, @schemas[source_name])
          unresolvable = resolved.nil? &&
            ref.start_with?("#/", "./", "http://", "https://")
          errors << "#{source_name}#{path}: unresolvable $ref '#{ref}'" if
            unresolvable
        end

        schema.each_child do |child, segment|
          collect_refs(child, source_name, errors, seen_refs,
                       "#{path}/#{segment}")
        end
      end

      class ValidationError < StandardError; end
    end
  end
end
