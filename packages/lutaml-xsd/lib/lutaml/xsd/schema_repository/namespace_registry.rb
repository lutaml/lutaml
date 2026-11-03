# frozen_string_literal: true

module Lutaml
  module Xsd
    class SchemaRepository
      # Internal helper for managing namespace prefix-to-URI mappings
      # Provides bidirectional lookups and conflict detection
      class NamespaceRegistry
        attr_reader :default_namespace

        def initialize
          @prefix_to_uri = {}
          @uri_to_prefixes = Hash.new { |h, k| h[k] = [] }
          @default_namespace = nil
        end

        # Register a namespace prefix-to-URI mapping
        # @param prefix [String] The namespace prefix
        # @param uri [String] The namespace URI
        # @param default [Boolean] Whether this is the default namespace
        def register(prefix, uri, default: false)
          return if prefix.nil? || uri.nil?

          # Check for conflicts
          if @prefix_to_uri.key?(prefix) && @prefix_to_uri[prefix] != uri
            warn "Warning: Prefix '#{prefix}' is already mapped to '#{@prefix_to_uri[prefix]}', " \
                 "overwriting with '#{uri}'"
          end

          @prefix_to_uri[prefix] = uri
          @uri_to_prefixes[uri] << prefix unless @uri_to_prefixes[uri].include?(prefix)

          @default_namespace = uri if default
        end

        # Register multiple namespace mappings
        # @param mappings [Hash, Array<NamespaceMapping>] Prefix-to-URI mappings
        def register_all(mappings)
          case mappings
          when Hash
            mappings.each { |prefix, uri| register(prefix, uri) }
          when Array
            mappings.each do |mapping|
              if mapping.is_a?(NamespaceMapping)
                register(mapping.prefix, mapping.uri)
              elsif mapping.is_a?(Hash)
                prefix = mapping[:prefix] || mapping["prefix"]
                uri = mapping[:uri] || mapping["uri"]
                register(prefix, uri)
              end
            end
          end
        end

        # Get namespace URI for a given prefix
        # @param prefix [String] The namespace prefix
        # @return [String, nil] The namespace URI or nil if not found
        def get_uri(prefix)
          @prefix_to_uri[prefix]
        end

        # Get all prefixes for a given namespace URI
        # @param uri [String] The namespace URI
        # @return [Array<String>] List of prefixes for this URI
        def get_prefixes(uri)
          @uri_to_prefixes[uri] || []
        end

        # Get the primary (first registered) prefix for a URI
        # @param uri [String] The namespace URI
        # @return [String, nil] The primary prefix or nil
        def get_primary_prefix(uri)
          get_prefixes(uri).first
        end

        # Check if a prefix is registered
        # @param prefix [String] The namespace prefix
        # @return [Boolean]
        def prefix_registered?(prefix)
          @prefix_to_uri.key?(prefix)
        end

        # Check if a URI is registered
        # @param uri [String] The namespace URI
        # @return [Boolean]
        def uri_registered?(uri)
          @uri_to_prefixes.key?(uri)
        end

        # Get all registered prefixes
        # @return [Array<String>]
        def all_prefixes
          @prefix_to_uri.keys
        end

        # Get all registered URIs
        # @return [Array<String>]
        def all_uris
          @uri_to_prefixes.keys
        end

        # Get all prefix-to-URI mappings
        # @return [Hash]
        def all_mappings
          @prefix_to_uri.dup
        end

        # Set the default namespace
        # @param uri [String] The default namespace URI
        def set_default_namespace(uri)
          @default_namespace = uri
        end

        # Clear all mappings
        def clear
          @prefix_to_uri.clear
          @uri_to_prefixes.clear
          @default_namespace = nil
        end

        # Get namespace mappings from parsed schemas
        # @param schemas [Array<Schema>] Parsed schema objects
        def extract_from_schemas(schemas)
          schemas.each do |schema|
            next unless schema.target_namespace

            # Try to find a commonly used prefix for this namespace
            # or create one from the namespace URI
            uri = schema.target_namespace
            next if uri_registered?(uri)

            # Extract prefix from common patterns or use a generated one
            prefix = extract_prefix_from_uri(uri)
            register(prefix, uri) unless prefix_registered?(prefix)
          end
        end

        private

        # Extract a reasonable prefix from a namespace URI
        # @param uri [String] The namespace URI
        # @return [String] A suggested prefix
        def extract_prefix_from_uri(uri)
          # Common namespace patterns
          case uri
          when %r{www\.w3\.org/2001/XMLSchema}
            "xs"
          when %r{www\.opengis\.net/gml}
            "gml"
          when %r{www\.w3\.org/1999/xlink}
            "xlink"
          else
            # Extract from path or use a hash-based approach
            parts = uri.split("/").reject(&:empty?)
            parts.last&.gsub(/[^a-zA-Z0-9]/, "") || "ns#{uri.hash.abs}"
          end
        end
      end
    end
  end
end
