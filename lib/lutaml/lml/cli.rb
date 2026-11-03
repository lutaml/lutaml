# frozen_string_literal: true

require 'thor'
require 'pathname'
require 'json'
require 'lutaml/lml'

module Lutaml
  module Cli
    # Thor CLI commands for LutaML DSL generation and validation.
    class LmlCommands < Thor
      include ::Lutaml::Lml::HasAttributes

      SUPPORTED_FORMATS = %w[yaml lutaml exp].freeze
      DEFAULT_INPUT_FORMAT = 'lutaml'
      DEFAULT_OUTPUT_FORMAT = 'svg'

      EXTENSION_FORMAT_MAP = {
        '.svg' => 'svg', '.svgz' => 'svgz',
        '.png' => 'png', '.gif' => 'gif', '.jpg' => 'jpg', '.jpeg' => 'jpeg',
        '.pdf' => 'pdf', '.ps' => 'ps', '.eps' => 'eps',
        '.dot' => 'dot', '.xdot' => 'xdot',
        '.fig' => 'fig', '.json' => 'json',
        '.imap' => 'imap', '.cmapx' => 'cmapx'
      }.freeze

      PARSE_HANDLERS = {
        'lutaml' => ->(path) { File.open(path) { |f| Lutaml::Lml.parse(f) } },
        'yaml' => ->(path) { Lutaml::Lml::YamlParser.parse(path.to_s) },
        'yml' => ->(path) { Lutaml::Lml::YamlParser.parse(path.to_s) },
        'exp' => lambda { |path|
          # EXPRESS is handled by expressir (the EXPRESS front), not lutaml.
          begin
            require 'expressir'
            require 'expressir/express/parser'
          rescue LoadError
            raise Thor::Error,
                  'EXPRESS (.exp) input requires the expressir gem: add ' \
                  '`gem "expressir"` to your Gemfile'
          end
          Expressir::Express::Parser.from_files([path.to_s])
        },
      }.freeze

      FORMATTER_ATTR_TARGETS = %i[graph edge node].freeze

      def initialize(*args)
        super
        # Graphviz is built lazily in #generate so commands that never
        # render (validate, format, ...) work without lutaml-graphviz.
        @formatter = ::Lutaml::Formatter::Elk.new if options[:layout] == 'elk'
        @out_object = $stdout
      end

      desc 'generate [PATHS]', 'Generate diagram output from LutaML DSL files'
      long_desc <<-DESC
        Generate diagram output from one or more LutaML DSL files.

        Supports multiple input formats (lutaml, yaml, exp) and can output
        to various formats (svg, png, dot, pdf, etc.).

        Examples:
          lutaml lml generate model.lutaml -o diagram.svg

          lutaml lml generate model.lutaml -o diagram.dot -t dot

          lutaml lml generate model.lutaml project.lutaml -o output/
      DESC
      method_option :output, type: :string, aliases: '-o',
                             desc: 'Output path (file or directory)'
      method_option :formatter, type: :string, aliases: '-f',
                                desc: 'Output formatter (default: graphviz)'
      method_option :type, type: :string, aliases: '-t',
                           desc: 'Output format type (svg, png, dot, etc.)'
      method_option :input_format, type: :string, aliases: '-i',
                                   desc: 'Input format (lutaml, yaml, exp)'
      method_option :graph, type: :string, aliases: '-g',
                            desc: 'Graph attributes (key=value,key2=value2)'
      method_option :edge, type: :string, aliases: '-e',
                           desc: 'Edge attributes (key=value,key2=value2)'
      method_option :node, type: :string, aliases: '-n',
                           desc: 'Node attributes (key=value,key2=value2)'
      method_option :all, type: :string, aliases: '-a',
                          desc: 'Set attributes for graph, edge, and node'
      method_option :layout, type: :string, enum: %w[graphviz elk], default: 'graphviz',
                             desc: 'Layout engine (elk requires the elkrb gem)'
      def generate(*paths)
        assert_input_paths(paths)

        @formatter ||= build_graphviz_formatter
        setup_options
        @paths = paths.map { |path| Pathname.new(path) }

        assert_output_path

        @paths.each { |input_path| process_single_file(input_path) }
      end

      desc 'validate [PATHS]', 'Validate LutaML DSL syntax'
      long_desc <<-DESC
        Validate the syntax of one or more LutaML DSL files.

        Checks for syntax errors and structural issues in the DSL files
        without generating output.

        Examples:
          lutaml lml validate model.lutaml

          lutaml lml validate model.lutaml project.lutaml
      DESC
      method_option :input_format, type: :string, aliases: '-i',
                                   desc: 'Input format (lutaml, yaml, exp)'
      method_option :format, type: :string, enum: %w[text json], default: 'text',
                             desc: 'Report format: text (default) or json'
      def validate(*paths)
        assert_input_paths(paths)
        @input_format = options[:input_format] || DEFAULT_INPUT_FORMAT
        diagnostics = paths.flat_map { |path| validate_single_file(path) }
        report_validation(diagnostics)
      end

      desc 'format [PATHS]', 'Render LML files in canonical form'
      long_desc <<-DESC
        Rewrite LML files into the RS 3001 canonical form (deterministic
        member order, two-space layout, canonical attribute forms and
        quoting).

        With --check, files are not modified: each non-canonical file is
        reported with a diff and the command exits 1.

        Examples:
          lutaml lml format model.lml

          lutaml lml format model.lml --check
      DESC
      method_option :check, type: :boolean, default: false,
                            desc: 'Report non-canonical files instead of rewriting them'
      def format(*paths)
        assert_input_paths(paths)

        noncanonical = paths.reject { |path| file_canonical?(path) }
        return if noncanonical.empty?

        exit 1
      end

      desc 'compile PATH', 'Compile LML model definitions into Ruby classes'
      long_desc <<-DESC
        Parse an LML file containing model definitions and compile them
        into Ruby classes that can be used to instantiate and validate data.

        With --namespace, classes are registered as constants in the given
        module (created if absent).

        With --schema, emits a JSON Schema or YAML Schema document for every
        compiled model instead of the compile listing. Schema output requires
        named classes, so --namespace defaults to Lutaml::Lml::Generated when omitted.

        Examples:
          lutaml lml compile models.lml

          lutaml lml compile models.lml --namespace MyModels

          lutaml lml compile models.lml --schema json -o schemas/

          lutaml lml compile models.lml --schema yaml -o widget.schema.yaml
      DESC
      method_option :namespace, type: :string, aliases: '-n',
                                desc: 'Register compiled classes in a module (created if absent)'
      method_option :schema, type: :string, enum: %w[json yaml],
                             desc: 'Emit JSON Schema or YAML Schema for the compiled models'
      method_option :output, type: :string, aliases: '-o',
                             desc: 'Schema output path (file for one model, directory for many)'
      def compile(path)
        raise Thor::Error, "File does not exist: #{path}" unless File.exist?(path)
        raise Thor::Error, "Expected a file, got directory: #{path}" if File.directory?(path)

        ns = options[:namespace] || (::Lutaml::Lml::ModelCompiler::DEFAULT_NAMESPACE if options[:schema])
        result = File.open(path) { |file| Lutaml::Lml::ModelCompiler.new(namespace: ns).compile(file) }
        return emit_schemas(result) if options[:schema]

        report_compilation(result)
      end

      no_commands do
        def report_compilation(result)
          result.each_key do |name|
            say "  compiled: #{name}", :green
          end
          say "\n#{result.size} class(es) compiled", :green
        end

        def emit_schemas(result)
          require 'lutaml/model/schema'
          if options[:output] && Pathname.new(options[:output]).directory?
            generator = "to_#{options[:schema]}"
            schemas = result.transform_values do |klass|
              Lutaml::Model::Schema.public_send(generator, klass, pretty: true)
            end
            write_schemas(schemas)
          else
            # One multi-root document covers every compiled model; each
            # root stays addressable under $defs by class name.
            schema = generate_multi_root_schema(result)
            return puts schema unless options[:output]

            File.write(options[:output], schema)
            say "Generated: #{options[:output]}", :green
          end
        end

        def generate_multi_root_schema(result)
          klass = options[:schema] == 'yaml' ? Lutaml::Model::Schema::YamlSchema : Lutaml::Model::Schema::JsonSchema
          klass.generate_many(result.values, pretty: true)
        end

        def write_schemas(schemas)
          target = Pathname.new(options[:output])
          if schemas.size > 1
            unless target.directory?
              raise Thor::Error,
                    'Output path must be a directory if multiple schemas ' \
                    'are generated'
            end
            write_schema_files(target, schemas)
          else
            target.write(schemas.values.first)
            say "Generated: #{target}", :green
          end
        end

        def write_schema_files(dir, schemas)
          schemas.each do |name, schema|
            file = dir.join("#{schema_file_stem(name)}.#{options[:schema]}")
            file.write(schema)
            say "Generated: #{file}", :green
          end
        end

        def schema_file_stem(name)
          name.split('::').last.gsub(/[^a-zA-Z0-9]+/, '_').downcase
        end

        def file_canonical?(path)
          input = Pathname.new(path)
          raise Thor::Error, "File does not exist: #{path}" unless input.exist?

          source = input.read
          canonical = canonical_source(source)
          return true if source == canonical

          if options[:check]
            say diff_source(source, canonical, path)
            say "#{path} is not canonical", :red
            false
          else
            input.write(canonical)
            say "Formatted: #{path}", :green
            true
          end
        end

        def canonical_source(source)
          document = Lutaml::Lml.parse_document(source)
          ::Lutaml::Formatter::Canonical.new(document).render
        end

        def diff_source(source, canonical, path)
          old_lines = source.lines.map(&:chomp)
          new_lines = canonical.lines.map(&:chomp)
          out = ["--- #{path}", "+++ #{path} (canonical)"]
          out.concat(diff_lines(old_lines, new_lines))
          out.join("\n")
        end

        def diff_lines(old_lines, new_lines)
          return ['(diff omitted: file too large)'] if old_lines.length * new_lines.length > 4_000_000

          table = Array.new(old_lines.length + 1) do
            Array.new(new_lines.length + 1, 0)
          end
          (old_lines.length - 1).downto(0) do |i|
            (new_lines.length - 1).downto(0) do |j|
              table[i][j] = if old_lines[i] == new_lines[j]
                              table[i + 1][j + 1] + 1
                            else
                              [table[i + 1][j], table[i][j + 1]].max
                            end
            end
          end
          walk_diff(old_lines, new_lines, table)
        end

        def walk_diff(old_lines, new_lines, table)
          result = []
          i = 0
          j = 0
          while i < old_lines.length && j < new_lines.length
            if old_lines[i] == new_lines[j]
              result << "  #{old_lines[i]}"
              i += 1
              j += 1
            elsif table[i + 1][j] >= table[i][j + 1]
              result << "- #{old_lines[i]}"
              i += 1
            else
              result << "+ #{new_lines[j]}"
              j += 1
            end
          end
          while i < old_lines.length
            result << "- #{old_lines[i]}"
            i += 1
          end
          while j < new_lines.length
            result << "+ #{new_lines[j]}"
            j += 1
          end
          result
        end

        def assert_input_paths(paths)
          return unless paths.empty?

          raise Thor::Error,
                'No input files provided. Please specify at least ' \
                'one .lutaml file.'
        end

        def assert_output_path
          return unless @output_path&.file? && @paths.length > 1

          raise Thor::Error,
                'Output path must be a directory if multiple input files ' \
                'are given'
        end

        def process_single_file(input_path)
          raise Thor::Error, "File does not exist: #{input_path}" unless input_path.exist?

          document = parse_document(input_path)
          result = @formatter.format(document)
          write_output(input_path, result)
        end

        def resolve_output_path(input_path)
          return @out_object unless @output_path

          path = @output_path
          path = path.join("#{input_path.basename('.*')}.#{@formatter.type}") if path.directory?
          path
        end

        def write_output(input_path, result)
          target = resolve_output_path(input_path)
          if target.is_a?(Pathname)
            target.open('wb+') { |f| f.write(result) }
            say "Generated: #{target}", :green
          else
            target.puts(result)
          end
        end

        def validate_single_file(path_string)
          input_path = Pathname.new(path_string)
          return [missing_file_diagnostic(input_path)] unless input_path.exist?

          document = parse_document(input_path)
          diagnostics = Lutaml::Lml::Validator.diagnostics(document)
          if diagnostics.any?
            if text_output?
              diagnostics.each do |diagnostic|
                say diagnostic_line(diagnostic),
                    (diagnostic.severity == 'warning' ? :yellow : :red)
              end
            end
          elsif text_output?
            say "✓ #{input_path}", :green
          end
          diagnostics
        rescue Thor::Error => e
          [contract_diagnostic('contract/LML-C02', e.message, input_path)]
        rescue Lutaml::Lml::Error => e
          [error_diagnostic(e, input_path)]
        rescue StandardError => e
          [contract_diagnostic('contract/LML-C03', e.message, input_path)]
        end

        def missing_file_diagnostic(input_path)
          contract_diagnostic('contract/LML-C01', 'File does not exist', input_path)
        end

        def contract_diagnostic(code, message, input_path)
          diagnostic = Diagnostic.build(code, message: message, file: input_path.to_s)
          say "✗ #{diagnostic}", :red if text_output?
          diagnostic
        end

        def error_diagnostic(error, input_path)
          diagnostic = error.diagnostic
          return diagnostic if diagnostic&.file

          Diagnostic.build(
            diagnostic&.code || 'parse/LML-001',
            message: diagnostic&.message || error.message.lines.first.to_s.strip,
            file: input_path.to_s,
            line: diagnostic&.line,
            column: diagnostic&.column,
            length: diagnostic&.length,
          )
        end

        def text_output?
          options[:format] != 'json'
        end

        def diagnostic_line(diagnostic)
          marker = diagnostic.severity == 'warning' ? '⚠' : '✗'
          "#{marker} #{diagnostic}"
        end

        def report_validation(diagnostics)
          errors = diagnostics.count { |diagnostic| diagnostic.severity != 'warning' }
          if options[:format] == 'json'
            puts JSON.pretty_generate(diagnostics.map(&:to_hash))
            exit 1 if errors.positive?
            return
          end

          if errors.positive?
            say "\nValidation failed with #{errors} error(s)", :red
            exit 1
          elsif diagnostics.any?
            say "\nAll files valid (#{diagnostics.size} warning(s))", :yellow
          else
            say "\nAll files valid!", :green
          end
        end

        def parse_document(input_path)
          handler = PARSE_HANDLERS[@input_format]
          return handler.call(input_path) if handler

          raise Thor::Error, "Unsupported input format: #{@input_format}"
        end

        # Graphviz rendering lives in the lutaml-graphviz gem so ruby-graphviz
        # never enters this gemspec; consumers add it to their own Gemfile.
        def build_graphviz_formatter
          require 'lutaml/graphviz'
          ::Lutaml::Formatter::Graphviz.new
        rescue LoadError
          raise Thor::Error,
                'Graphviz output requires the lutaml-graphviz gem: add ' \
                '`gem "lutaml-graphviz"` to your Gemfile (or use --layout elk)'
        end

        def setup_options
          @formatter = options[:formatter] if options[:formatter]
          @output_path = Pathname.new(options[:output]) if options[:output]
          @input_format = options[:input_format] || DEFAULT_INPUT_FORMAT
          @type = resolve_output_type

          setup_formatter_options
        end

        def resolve_output_type
          return options[:type] if options[:type]
          return DEFAULT_OUTPUT_FORMAT unless @output_path

          ext = @output_path.extname.downcase
          EXTENSION_FORMAT_MAP.fetch(ext, DEFAULT_OUTPUT_FORMAT)
        end

        def parse_kv_string(str)
          str.split(',').to_h do |pair|
            key, value = pair.split('=', 2)
            [key.strip, value&.strip]
          end
        end

        def apply_kv_to_formatter(option_key, str)
          targets = option_key == :all ? FORMATTER_ATTR_TARGETS : [option_key]
          parse_kv_string(str).each do |key, value|
            targets.each { |t| @formatter.public_send(t)[key] = value }
          end
        end

        def setup_formatter_options
          return unless @formatter

          @formatter.type = @type if @type

          FORMATTER_ATTR_TARGETS.each do |target|
            apply_kv_to_formatter(target, options[target]) if options[target]
          end
          apply_kv_to_formatter(:all, options[:all]) if options[:all]
        end
      end

      def self.exit_on_failure?
        true
      end
    end
  end
end
