# frozen_string_literal: true

require "zip"
require "tempfile"

module Expressir
  module TestFixtures
    # Fixture helper for creating test packages with various nil scenarios
    class PackageFixtures
      class << self
        # Create a package with nil metadata fields
        def create_nil_metadata_package(path)
          Zip::File.open(path, create: true) do |zip|
            # Metadata with nil fields
            metadata_hash = {
              "name" => "Test Package",
              "version" => "1.0.0",
              "description" => nil,
              "created_at" => nil,
              "created_by" => nil,
              "express_mode" => nil,
              "resolution_mode" => nil,
              "serialization_format" => nil,
              "files" => nil,
              "schemas" => nil,
            }

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata_hash.to_yaml)
            end

            # Empty repository
            empty_repo = Expressir::Model::Repository.new
            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(empty_repo))
            end

            # Empty indexes
            add_empty_indexes(zip)
            add_empty_manifest(zip)
          end
        end

        # Create a package with empty string metadata fields
        def create_empty_metadata_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata_hash = {
              "name" => "",
              "version" => "",
              "description" => "",
              "created_at" => "",
              "created_by" => "",
              "express_mode" => "",
              "resolution_mode" => "",
              "serialization_format" => "",
            }

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata_hash.to_yaml)
            end

            empty_repo = Expressir::Model::Repository.new
            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(empty_repo))
            end

            add_empty_indexes(zip)
            add_empty_manifest(zip)
          end
        end

        # Create a package with completely empty repository
        def create_empty_repository_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata = Expressir::Package::Metadata.new(
              name: "Empty Repository Package",
              version: "1.0.0",
              schemas: 0,
              files: 0,
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end

            # Repository with explicitly nil schemas
            empty_repo = Expressir::Model::Repository.new
            empty_repo.instance_variable_set(:@schemas, nil)

            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(empty_repo))
            end

            add_empty_indexes(zip)
            add_empty_manifest(zip)
          end
        end

        # Create a package with schemas but nil entities/types/functions
        def create_nil_collections_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata = Expressir::Package::Metadata.new(
              name: "Nil Collections Package",
              version: "1.0.0",
              schemas: 1,
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end

            # Create schema with nil collections
            schema = Expressir::Model::Declarations::Schema.new(
              id: "test_schema",
              file: nil,
            )

            # Set collections to nil
            schema.instance_variable_set(:@entities, nil)
            schema.instance_variable_set(:@types, nil)
            schema.instance_variable_set(:@functions, nil)
            schema.instance_variable_set(:@procedures, nil)
            schema.instance_variable_set(:@rules, nil)

            repo = Expressir::Model::Repository.new
            repo.add_schema(schema)

            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(repo))
            end

            add_empty_indexes(zip)
            add_manifest_with_schema(zip, "test_schema")
          end
        end

        # Create a package with entities that have nil attributes
        def create_nil_attributes_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata = Expressir::Package::Metadata.new(
              name: "Nil Attributes Package",
              version: "1.0.0",
              schemas: 1,
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end

            # Create entity with nil attributes
            entity = Expressir::Model::Declarations::Entity.new(
              id: "test_entity",
            )
            entity.instance_variable_set(:@attributes, nil)
            entity.instance_variable_set(:@derived_attributes, nil)
            entity.instance_variable_set(:@inverse_attributes, nil)

            schema = Expressir::Model::Declarations::Schema.new(
              id: "test_schema",
              file: nil,
            )
            schema.entities = [entity]

            repo = Expressir::Model::Repository.new
            repo.add_schema(schema)

            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(repo))
            end

            add_empty_indexes(zip)
            add_manifest_with_schema(zip, "test_schema")
          end
        end

        # Create a package missing critical files
        def create_missing_files_package(path)
          Zip::File.open(path, create: true) do |zip|
            # Only add metadata, missing everything else
            metadata = Expressir::Package::Metadata.new(
              name: "Missing Files Package",
              version: "1.0.0",
              resolution_mode: "resolved",
              serialization_format: "marshal",
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end
            # Missing repository.marshal, indexes, manifest
          end
        end

        # Create a package with corrupted files
        def create_corrupted_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata = Expressir::Package::Metadata.new(
              name: "Corrupted Package",
              version: "1.0.0",
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end

            # Add corrupted marshal data
            zip.get_output_stream("repository.marshal") do |s|
              s.write("corrupted binary data")
            end

            # Add corrupted indexes
            zip.get_output_stream("entity_index.marshal") do |s|
              s.write("corrupted index data")
            end
          end
        end

        # Create a package with malformed YAML
        def create_malformed_yaml_package(path)
          Zip::File.open(path, create: true) do |zip|
            # Malformed YAML metadata
            zip.get_output_stream("metadata.yaml") do |s|
              s.write("invalid: yaml: syntax: [unclosed")
            end
          end
        end

        # Create a package for testing search with no results
        def create_empty_search_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata = Expressir::Package::Metadata.new(
              name: "Empty Search Package",
              version: "1.0.0",
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end

            # Repository with schema but no searchable elements
            schema = Expressir::Model::Declarations::Schema.new(
              id: "empty_schema",
              file: nil,
            )
            schema.entities = []
            schema.types = []
            schema.functions = []

            repo = Expressir::Model::Repository.new
            repo.add_schema(schema)
            repo.build_indexes

            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(repo))
            end

            add_empty_indexes(zip)
            add_manifest_with_schema(zip, "empty_schema")
          end
        end

        # Create a package with mixed nil and valid data
        def create_mixed_data_package(path)
          Zip::File.open(path, create: true) do |zip|
            metadata = Expressir::Package::Metadata.new(
              name: "Mixed Data Package",
              version: "1.0.0",
              description: "Valid description",
              created_by: nil, # nil field
              express_mode: "include_all",
            )

            zip.get_output_stream("metadata.yaml") do |s|
              s.write(metadata.to_yaml)
            end

            # Schema with some nil collections, some valid
            schema = Expressir::Model::Declarations::Schema.new(
              id: "mixed_schema",
              file: nil,
            )

            # Valid entity
            entity = Expressir::Model::Declarations::Entity.new(
              id: "valid_entity",
            )
            entity.attributes = []

            schema.entities = [entity]
            schema.types = nil # nil collection
            schema.functions = []

            repo = Expressir::Model::Repository.new
            repo.add_schema(schema)

            zip.get_output_stream("repository.marshal") do |s|
              s.write(Marshal.dump(repo))
            end

            add_empty_indexes(zip)
            add_manifest_with_schema(zip, "mixed_schema")
          end
        end

        private

        # Add empty index files to package
        def add_empty_indexes(zip)
          zip.get_output_stream("entity_index.marshal") do |s|
            s.write(Marshal.dump({}))
          end
          zip.get_output_stream("type_index.marshal") do |s|
            s.write(Marshal.dump({}))
          end
          zip.get_output_stream("reference_index.marshal") do |s|
            s.write(Marshal.dump({}))
          end
        end

        # Add empty manifest to package
        def add_empty_manifest(zip)
          manifest = { schemas: [] }
          zip.get_output_stream("manifest.yaml") do |s|
            s.write(manifest.to_yaml)
          end
        end

        # Add manifest with single schema
        def add_manifest_with_schema(zip, schema_id)
          manifest = {
            schemas: [
              {
                id: schema_id,
                path: "#{schema_id}.exp",
              },
            ],
          }
          zip.get_output_stream("manifest.yaml") do |s|
            s.write(manifest.to_yaml)
          end
        end
      end
    end
  end
end
