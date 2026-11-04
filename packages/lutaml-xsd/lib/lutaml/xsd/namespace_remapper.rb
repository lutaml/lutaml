# frozen_string_literal: true

module Lutaml
  module Xsd
    # Remaps namespace prefixes in a package
    # Single responsibility: create new package with updated prefixes
    class NamespaceRemapper
      attr_reader :repository

      def initialize(repository)
        @repository = repository
      end

      # Remap prefixes
      # @param changes [Hash] Mapping of old_prefix => new_prefix
      # @return [SchemaRepository] New repository with updated mappings
      def remap(changes)
        # Validate changes
        validate_changes(changes)

        # Apply changes to namespace mappings
        new_mappings = apply_changes(changes)

        # Create new repository with updated mappings
        repository_with_new_mappings(new_mappings)
      end

      private

      def validate_changes(changes)
        changes.each do |old_prefix, new_prefix|
          # Check old prefix exists
          unless repository.namespace_mappings.any? do |m|
            m.prefix == old_prefix
          end
            raise ArgumentError,
                  "Prefix '#{old_prefix}' not found in repository"
          end

          # Check new prefix is valid
          if new_prefix.nil? || new_prefix.empty?
            raise ArgumentError,
                  "New prefix cannot be empty"
          end

          # Check new prefix doesn't conflict (unless it's being swapped)
          if repository.namespace_mappings.any? do |m|
            m.prefix == new_prefix
          end &&
              !changes.key?(new_prefix)
            raise ArgumentError,
                  "Prefix '#{new_prefix}' already exists in repository"
          end
        end
      end

      def apply_changes(changes)
        # Create new mappings with updated prefixes
        repository.namespace_mappings.map do |mapping|
          new_prefix = changes[mapping.prefix] || mapping.prefix
          NamespaceMapping.new(prefix: new_prefix, uri: mapping.uri)
        end
      end

      def repository_with_new_mappings(new_mappings)
        # Create a new repository instance with updated namespace mappings
        new_repo = SchemaRepository.new(
          files: repository.files,
          schema_location_mappings: repository.schema_location_mappings,
          namespace_mappings: new_mappings,
        )

        # Copy internal state from original repository
        copy_internal_state(new_repo)

        new_repo
      end

      def copy_internal_state(new_repo)
        original_store = repository.instance_variable_get(:@parsed_schemas)
        new_store = Lutaml::Store::BasicStore.new(adapter_type: :memory)
        original_store.all.each { |k, v| new_store.set(k, v) }
        new_repo.instance_variable_set(:@parsed_schemas, new_store)

        # Copy resolution state
        new_repo.instance_variable_set(:@resolved,
                                       repository.instance_variable_get(:@resolved))
        new_repo.instance_variable_set(:@validated,
                                       repository.instance_variable_get(:@validated))
        new_repo.instance_variable_set(:@lazy_load,
                                       repository.instance_variable_get(:@lazy_load))
        new_repo.instance_variable_set(:@verbose,
                                       repository.instance_variable_get(:@verbose))

        # Re-register namespace mappings with the new registry
        namespace_registry = new_repo.instance_variable_get(:@namespace_registry)
        new_repo.namespace_mappings.each do |mapping|
          namespace_registry.register(mapping.prefix, mapping.uri)
        end

        # Rebuild type index with new namespace registry
        return unless repository.instance_variable_get(:@resolved)

        type_index = new_repo.instance_variable_get(:@type_index)
        all_schemas = new_repo.all_schemas
        type_index.build_from_schemas(all_schemas)
      end
    end
  end
end
