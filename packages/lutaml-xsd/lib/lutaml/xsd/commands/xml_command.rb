# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # XML operations commands (MECE category)
      # Handles all XML validation and processing operations
      class XmlCommand < Thor
        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "validate FILES SCHEMA",
             "Validate XML instance files against XSD schema"
        long_desc <<~DESC
          Validate one or more XML instance files against an XSD schema package.

          Examples:
            # Validate single file
            lutaml-xsd xml validate instance.xml schemas.lxr

            # Validate multiple files
            lutaml-xsd xml validate file1.xml file2.xml schemas.lxr

            # Validate with glob pattern
            lutaml-xsd xml validate "*.xml" schemas.lxr

            # Validate with custom configuration
            lutaml-xsd xml validate instance.xml schemas.lxr --config validation.yml

            # Output as JSON
            lutaml-xsd xml validate instance.xml schemas.lxr --format json

            # Limit error output
            lutaml-xsd xml validate instance.xml schemas.lxr --max-errors 5
        DESC
        option :config,
               type: :string,
               desc: "Path to validation configuration file"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        option :max_errors,
               type: :numeric,
               default: 10,
               desc: "Maximum number of errors to display per file"
        def validate(*args)
          if args.length < 2
            error "Usage: lutaml-xsd xml validate FILES SCHEMA [options]"
            raise CommandError
          end

          schema = args.pop
          files = args
          require_relative "validate_command"
          ValidateCommand.new(files, schema, options).run
        end

        private

        def error(message)
          warn "ERROR: #{message}"
        end
      end
    end
  end
end
