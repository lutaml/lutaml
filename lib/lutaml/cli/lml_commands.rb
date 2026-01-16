# frozen_string_literal: true

require "thor"
require "pathname"
require_relative "../formatter"
require_relative "../uml/has_attributes"
require_relative "../uml/parsers/attribute"
require_relative "../uml/parsers/dsl"
require_relative "../uml/parsers/yaml"

module Lutaml
  module Cli
    # LmlCommands provides CLI commands for LutaML DSL diagram generation
    #
    # This subcommand handles operations related to the LutaML textual DSL
    # notation (.lutaml files), including generating diagrams and validating
    # DSL syntax.
    class LmlCommands < Thor
      include ::Lutaml::Uml::HasAttributes

      SUPPORTED_FORMATS = %w[yaml lutaml exp].freeze
      DEFAULT_INPUT_FORMAT = "lutaml"

      def initialize(*args)
        super
        # Only initialize Graphviz formatter if available
        if defined?(::Lutaml::Formatter::Graphviz)
          @formatter = ::Lutaml::Formatter::Graphviz.new
        end
        @out_object = $stdout
      end

      desc "generate [PATHS]", "Generate diagram output from LutaML DSL files"
      long_desc <<-DESC
        Generate diagram output from one or more LutaML DSL files.

        Supports multiple input formats (lutaml, yaml, exp) and can output
        to various formats depending on the configured formatter.

        Examples:
          lutaml lml generate model.lutaml -o diagram.png

          lutaml lml generate model.lutaml -o diagram.dot -t dot

          lutaml lml generate model.lutaml project.lutaml -o output/
      DESC
      method_option :output, type: :string, aliases: "-o",
                             desc: "Output path (file or directory)"
      method_option :formatter, type: :string, aliases: "-f",
                                desc: "Output formatter (default: graphviz)"
      method_option :type, type: :string, aliases: "-t",
                           desc: "Output format type (png, svg, dot, etc.)"
      method_option :input_format, type: :string, aliases: "-i",
                                   desc: "Input format (lutaml, yaml, exp)"
      method_option :graph, type: :string, aliases: "-g",
                            desc: "Graph attributes (key=value,key2=value2)"
      method_option :edge, type: :string, aliases: "-e",
                           desc: "Edge attributes (key=value,key2=value2)"
      method_option :node, type: :string, aliases: "-n",
                           desc: "Node attributes (key=value,key2=value2)"
      method_option :all, type: :string, aliases: "-a",
                          desc: "Set attributes for graph, edge, and node"
      def generate(*paths) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        if paths.empty?
          raise Thor::Error,
                "No input files provided. Please specify at least " \
                "one .lutaml file."
        end

        setup_options
        @paths = paths.map { |path| Pathname.new(path) }

        if @output_path&.file? && @paths.length > 1
          raise Thor::Error,
                "Output path must be a directory if multiple input files " \
                "are given"
        end

        @paths.each do |input_path|
          unless input_path.exist?
            raise Thor::Error, "File does not exist: #{input_path}"
          end

          document = Lutaml::Parser
            .parse_into_document(File.new(input_path), @input_format)
            .first
          result = @formatter.format(document)

          if @output_path
            output_path = @output_path
            if output_path.directory?
              output_path = output_path.join(
                input_path.basename(".*").to_s + ".#{@formatter.type}",
              )
            end

            output_path.open("w+") { |file| file.write(result) }
            say "Generated: #{output_path}", :green
          else
            @out_object.puts(result)
          end
        end
      end

      desc "validate [PATHS]", "Validate LutaML DSL syntax"
      long_desc <<-DESC
        Validate the syntax of one or more LutaML DSL files.

        Checks for syntax errors and structural issues in the DSL files
        without generating output.

        Examples:
          lutaml lml validate model.lutaml

          lutaml lml validate model.lutaml project.lutaml
      DESC
      def validate(*paths) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if paths.empty?
          raise Thor::Error,
                "No input files provided. Please specify at least " \
                "one .lutaml file."
        end

        errors = []
        paths.each do |path_string|
          input_path = Pathname.new(path_string)

          unless input_path.exist?
            errors << "File does not exist: #{input_path}"
            next
          end

          begin
            Lutaml::Parser.parse_into_document(
              File.new(input_path),
              DEFAULT_INPUT_FORMAT,
            )
            say "✓ #{input_path}", :green
          rescue StandardError => e
            errors << "#{input_path}: #{e.message}"
            say "✗ #{input_path}: #{e.message}", :red
          end
        end

        if errors.any?
          say "\nValidation failed with #{errors.size} error(s)", :red
          exit 1
        else
          say "\nAll files valid!", :green
        end
      end

      no_commands do # rubocop:disable Metrics/BlockLength
        def setup_options # rubocop:disable Metrics/AbcSize
          @formatter = options[:formatter] if options[:formatter]
          @type = options[:type] if options[:type]
          @output_path = Pathname.new(options[:output]) if options[:output]
          @input_format = options[:input_format] || DEFAULT_INPUT_FORMAT

          setup_formatter_options
        end

        def setup_formatter_options # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return unless @formatter

          @formatter.type = @type if @type

          if options[:graph]
            Parsers::Attribute.parse(options[:graph]).each do |key, value|
              @formatter.graph[key] = value
            end
          end

          if options[:edge]
            Parsers::Attribute.parse(options[:edge]).each do |key, value|
              @formatter.edge[key] = value
            end
          end

          if options[:node]
            Parsers::Attribute.parse(options[:node]).each do |key, value|
              @formatter.node[key] = value
            end
          end

          if options[:all]
            Parsers::Attribute.parse(options[:all]).each do |key, value|
              @formatter.graph[key] = value
              @formatter.edge[key] = value
              @formatter.node[key] = value
            end
          end
        end
      end

      def self.exit_on_failure?
        true
      end
    end
  end
end
