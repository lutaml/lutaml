# frozen_string_literal: true

module Expressir
  # Base error class with details support
  class Error < StandardError
    attr_reader :details

    def initialize(message = nil, details: nil)
      @details = details
      super(message)
    end
  end

  # File/Resource Errors
  class FileNotFoundError < Error
    attr_reader :file_path, :file_type

    def initialize(file_path, file_type: nil)
      @file_path = file_path
      @file_type = file_type
      super("#{file_type || 'File'} not found: #{file_path}")
    end
  end

  class ManifestNotFoundError < FileNotFoundError
    def initialize(file_path)
      super(file_path, file_type: "Manifest file")
    end
  end

  class PackageNotFoundError < FileNotFoundError
    def initialize(file_path)
      super(file_path, file_type: "Package file")
    end
  end

  class SchemaNotFoundError < FileNotFoundError
    def initialize(file_path)
      super(file_path, file_type: "Schema file")
    end
  end

  # Usage/Argument Errors
  class UsageError < Error
    attr_reader :usage_hint

    def initialize(message, usage_hint: nil)
      @usage_hint = usage_hint
      super(message)
    end
  end

  class MissingRequiredArgumentError < UsageError; end

  class InvalidOptionError < UsageError
    attr_reader :option_name, :valid_options

    def initialize(option_name, value, valid_options: nil)
      @option_name = option_name
      @valid_options = valid_options
      msg = "Invalid value '#{value}' for #{option_name}"
      msg += ". Valid options: #{valid_options.join(', ')}" if valid_options
      super(msg)
    end
  end

  # Validation Errors
  class ValidationError < Error
    attr_reader :errors

    def initialize(message, errors: [])
      @errors = errors
      super(message)
    end
  end

  class ManifestValidationError < ValidationError; end
  class SchemaValidationError < ValidationError; end

  class ReferentialIntegrityError < ValidationError
    attr_reader :unresolved_references

    def initialize(unresolved_references,
message: "Referential integrity check failed")
      @unresolved_references = unresolved_references
      super(message)
    end
  end

  class NoValidSchemaPathsError < ValidationError
    def initialize(message = "No valid schema paths found")
      super
    end
  end

  # Command Errors (for rescue blocks)
  class CommandError < Error
    attr_reader :command_name

    def initialize(message, command_name: nil)
      @command_name = command_name
      super(message)
    end
  end

  class PackageBuildError < CommandError; end
  class PackageReadError < CommandError; end
  class PackageExtractError < CommandError; end
  class PackageValidationError < CommandError; end
  class PackageListError < CommandError; end
  class PackageSearchError < CommandError; end
  class PackageTreeError < CommandError; end
end
