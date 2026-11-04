# frozen_string_literal: true

module Expressir
  module Package
    # Package metadata with serialization support
    # Stores configuration and statistics for LER packages
    class Metadata < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :version, :string
      attribute :description, :string
      attribute :created_at, :string
      attribute :created_by, :string, default: -> { "expressir" }
      attribute :expressir_version, :string
      attribute :express_mode, :string, default: -> { "include_all" }
      attribute :resolution_mode, :string, default: -> { "resolved" }
      attribute :serialization_format, :string, default: -> { "marshal" }
      attribute :files, :integer
      attribute :schemas, :integer

      yaml do
        map "name", to: :name
        map "version", to: :version
        map "description", to: :description
        map "created_at", to: :created_at
        map "created_by", to: :created_by
        map "expressir_version", to: :expressir_version
        map "express_mode", to: :express_mode
        map "resolution_mode", to: :resolution_mode
        map "serialization_format", to: :serialization_format
        map "files", to: :files
        map "schemas", to: :schemas
      end

      # Validate metadata configuration
      # @return [Hash] Validation result with :valid? and :errors
      def validate
        errors = []

        errors << "name is required" if name.nil? || name.empty?
        errors << "version is required" if version.nil? || version.empty?

        unless %w[include_all allow_external].include?(express_mode)
          errors << "express_mode must be 'include_all' or 'allow_external'"
        end

        unless %w[resolved bare].include?(resolution_mode)
          errors << "resolution_mode must be 'resolved' or 'bare'"
        end

        unless %w[marshal json yaml].include?(serialization_format)
          errors << "serialization_format must be 'marshal', 'json', or 'yaml'"
        end

        {
          valid?: errors.empty?,
          errors: errors,
        }
      end

      # Convert metadata to hash
      # @return [Hash] Metadata as hash
      def to_h
        {
          "name" => name,
          "version" => version,
          "description" => description,
          "created_at" => created_at,
          "created_by" => created_by,
          "expressir_version" => expressir_version,
          "express_mode" => express_mode,
          "resolution_mode" => resolution_mode,
          "serialization_format" => serialization_format,
          "files" => files,
          "schemas" => schemas,
        }
      end
    end
  end
end
