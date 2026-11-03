# frozen_string_literal: true

require "thor"
require "json"
require "yeptris"

module Lutaml
  module Jsonschema
    class Cli < Thor
      desc "spa SCHEMA_FILES...",
           "Generate SPA documentation from JSON Schema files"
      option :output, aliases: "-o", type: :string, default: "output",
                      desc: "Output directory"
      option :config, aliases: "-c", type: :string,
                      desc: "Path to YAML configuration file"
      option :title, type: :string, desc: "Documentation title"
      option :theme, type: :string, desc: "Theme (light/dark)"
      option :logo, type: :string, desc: "Sidebar header logo URL"
      option :subtitle, type: :string, desc: "Sidebar subtitle text"
      option :diff, type: :array, default: [],
                    desc: "Baseline schema file(s) to report changes against"
      option :remote, type: :boolean, default: false,
                      desc: "Allow fetching remote HTTP(S) $refs"
      option :remote_cache, type: :string,
                            desc: "Directory for caching remote documents"
      def spa(*schema_files)
        raise Error, "No schema files provided" if schema_files.empty?

        config = load_config(options[:config])
        config.output_path = options[:output] if options[:output]
        config.title = options[:title] if options[:title]
        config.theme = options[:theme] if options[:theme]
        config.apply_appearance_overrides(logo: options[:logo],
                                          subtitle: options[:subtitle])

        schema_set = SchemaSet.load_from_files(*schema_files, **remote_options)
        baseline = load_baseline(options[:diff])
        generator = Spa::Generator.new(schema_set, config.output_path,
                                       metadata: config.to_metadata,
                                       baseline: baseline)
        generator.generate
        puts "SPA documentation generated at #{config.output_path}/index.html"
      rescue Errno::ENOENT => e
        abort "Error: #{e.message}"
      end

      desc "combine SCHEMA_FILES...",
           "Combine multiple JSON Schema files into one"
      option :output, aliases: "-o", type: :string, default: "-",
                      desc: "Output file path (use - for stdout)"
      option :remote, type: :boolean, default: false,
                      desc: "Allow fetching remote HTTP(S) $refs"
      option :remote_cache, type: :string,
                            desc: "Directory for caching remote documents"
      def combine(*schema_files)
        raise Error, "No schema files provided" if schema_files.empty?

        schema_set = SchemaSet.load_from_files(*schema_files, **remote_options)
        combined = schema_set.bundle
        json = JSON.pretty_generate(Yeptris::JSON.load(combined.to_json))

        if options[:output] == "-"
          $stdout.write(json)
        else
          File.write(options[:output], json)
          puts "Combined schema written to #{options[:output]}"
        end
      rescue Errno::ENOENT => e
        abort "Error: #{e.message}"
      end

      EXPORT_FORMATS = %w[cddl openapi xsd adoc lml].freeze

      desc "export SCHEMA_FILES...", "Export schemas (cddl|openapi|xsd|adoc)"
      option :format, aliases: "-f", type: :string, default: "cddl",
                      desc: "Export format (cddl, openapi, xsd, adoc, lml)"
      option :embeddable, type: :boolean, default: false,
                          desc: "adoc: drop the document title and namespace anchors for Metanorma include::"
      option :output, aliases: "-o", type: :string, default: "-",
                      desc: "Output file path (use - for stdout)"
      def export(*schema_files)
        raise Error, "No schema files provided" if schema_files.empty?

        format = options[:format]
        unless EXPORT_FORMATS.include?(format)
          raise Error, "Unsupported export format: #{format} " \
                       "(supported: #{EXPORT_FORMATS.join(', ')})"
        end

        schema_set = SchemaSet.load_from_files(*schema_files)
        text = render_export(format, schema_set)

        if options[:output] == "-"
          $stdout.write(text)
        else
          File.write(options[:output], text)
          puts "#{format} written to #{options[:output]}"
        end
      rescue Errno::ENOENT => e
        abort "Error: #{e.message}"
      end

      desc "diff OLD_SCHEMA NEW_SCHEMA",
           "Compare two schema documents (exits 1 on breaking changes)"
      option :format, aliases: "-f", type: :string, default: "text",
                      desc: "Output format (text/json)"
      def diff(old_file, new_file)
        old_schema = Schema.from_json(File.read(old_file))
        new_schema = Schema.from_json(File.read(new_file))
        changes = Diff.between(old_schema, new_schema)

        emit_diff(changes)
        exit(1) if changes.any? { |c| c.classification == Diff::BREAKING }
      rescue Errno::ENOENT => e
        abort "Error: #{e.message}"
      end

      desc "validate SCHEMA_FILE",
           "Validate a JSON Schema file against its dialect meta-schema"
      option :format, aliases: "-f", type: :string, default: "text",
                      desc: "Output format (text/json)"
      def validate(schema_file)
        data = File.read(schema_file)
        json = Yeptris::JSON.load(data)
        Schema.from_json(data)

        result = validation_result(json)
        emit_validation_result(schema_file, result)
        return if result[:errors].empty?

        abort "#{schema_file}: #{result[:errors].length} validation error(s)"
      rescue Yeptris::JSON::ParseError, JSON::ParserError => e
        abort "Invalid JSON: #{e.message}"
      rescue Errno::ENOENT => e
        abort "Error: #{e.message}"
      end

      desc "version", "Show version"
      def version
        puts "lutaml-jsonschema #{VERSION}"
      end

      private

      def load_config(path)
        return Configuration.new unless path

        Configuration.load_from_file(path)
      rescue Errno::ENOENT
        abort "Configuration file not found: #{path}"
      end

      def remote_options
        {
          allow_remote: options[:remote],
          remote_cache_dir: options[:remote_cache],
        }.compact
      end

      def load_baseline(files)
        return nil if files.empty?

        SchemaSet.load_from_files(*files, **remote_options)
      end

      def emit_diff(changes)
        if options[:format] == "json"
          puts JSON.pretty_generate(changes.map(&:to_h))
          return
        end

        changes.each do |change|
          puts "#{change.classification.to_s.upcase} #{change.pointer}: " \
               "#{change.detail}"
        end
        puts "No changes" if changes.empty?
      end

      def render_export(format, schema_set)
        case format
        when "cddl" then Exports::Cddl.new(schema_set).render
        when "adoc" then Exports::Adoc.new(schema_set, embeddable: options[:embeddable]).render
        when "openapi" then Exports::Openapi.new(schema_set).render
        when "xsd" then Exports::Xsd.new(schema_set).render
        when "lml" then Exports::Lml.new(schema_set).render
        end
      end

      def validate_structure(json)
        errors = []
        errors << "Missing $schema" unless json.key?("$schema")
        errors << "Missing type" unless json.key?("type")

        errors << "properties must be an object" if json.key?("properties") && !json["properties"].is_a?(Hash)

        errors << "required must be an array" if json.key?("required") && !json["required"].is_a?(Array)

        errors
      end

      def validation_result(json)
        unless json.is_a?(Hash)
          return {
            dialect: :unspecified,
            errors: ["schema document must be a JSON object " \
                     "(boolean schemas are not supported)"],
            warnings: [],
          }
        end

        dialect = Dialect.detect(json["$schema"])
        errors = validate_structure(json).dup
        warnings = []

        if Validator.supported?(dialect)
          Validator.validate(json, dialect).each do |meta_error|
            pointer = meta_error.pointer.empty? ? "/" : meta_error.pointer
            errors << "#{pointer}: #{meta_error.message}"
          end
        else
          warnings << "no $schema or unsupported dialect; meta-schema validation skipped"
        end

        { dialect: dialect, errors: errors, warnings: warnings }
      end

      def emit_validation_result(file, result)
        if options[:format] == "json"
          puts JSON.pretty_generate(
            file: file,
            dialect: result[:dialect].to_s,
            valid: result[:errors].empty?,
            errors: result[:errors],
            warnings: result[:warnings],
          )
          return
        end

        result[:warnings].each { |warning| warn "  warning: #{warning}" }
        if result[:errors].empty?
          puts "#{file}: valid"
        else
          result[:errors].each { |error| warn "  #{error}" }
        end
      end
    end
  end
end
