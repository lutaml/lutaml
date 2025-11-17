# frozen_string_literal: true

require "liquid"
require "json"
require "fileutils"
require_relative "configuration"
require_relative "data_transformer"
require_relative "search_index_builder"
require_relative "id_generator"

module Lutaml
  module UmlRepository
    module StaticSite
      # Main static site generator for LutaML UML Browser.
      #
      # Follows Dependency Inversion Principle by injecting dependencies
      # and using external configuration instead of hardcoded values.
      #
      # @example Single-file generation
      #   config = Configuration.load
      #   generator = Generator.new(repository, config: config, mode: :single_file)
      #   generator.generate
      #
      # @example With dependency injection
      #   generator = Generator.new(repository,
      #     config: custom_config,
      #     id_generator: custom_id_gen,
      #     data_transformer: custom_transformer
      #   )
      class Generator
        attr_reader :repository, :config, :options

        # Initialize generator with dependency injection
        #
        # @param repository [UmlRepository] The repository to generate site for
        # @param options [Hash] Generation options
        # @option options [Configuration] :config Configuration instance (default: auto-loaded)
        # @option options [IDGenerator] :id_generator ID generator instance
        # @option options [DataTransformer] :data_transformer Data transformer instance
        # @option options [SearchIndexBuilder] :search_builder Search index builder instance
        # @option options [Symbol] :mode Output mode (:single_file or :multi_file)
        # @option options [String] :output Output path
        # @option options [Boolean] :minify Minify output (overrides config)
        def initialize(repository, options = {})
          @repository = repository
          @config = options[:config] || Configuration.load(options[:config_path])
          @options = build_options(options)

          # Dependency injection for testability
          @id_generator = options[:id_generator] || IDGenerator.new
          @data_transformer = options[:data_transformer] ||
            create_data_transformer
          @search_builder = options[:search_builder] ||
            create_search_builder

          @liquid = setup_liquid
        end

        # Generate the static site
        #
        # @return [String] Path to generated output
        def generate
          case @options[:mode]
          when :single_file
            generate_single_file
          when :multi_file
            generate_multi_file
          else
            raise ArgumentError,
                  "Invalid mode: #{@options[:mode]}. Use :single_file or :multi_file"
          end
        end

        private

        # Build final options merging user options with configuration
        def build_options(user_options)
          # Priority: user_options > config > defaults
          defaults = {
            mode: :single_file,
            output: determine_default_output,
          }

          config_options = {
            title: @config.ui&.title,
            description: @config.ui&.description,
            minify: if user_options[:mode] == :single_file
                      @config.output&.single_file&.minify
                    else
                      @config.output&.multi_file&.minify
                    end,
            template_path: parse_template_path || default_template_path,
          }.compact

          defaults.merge(config_options).merge(user_options)
        end

        def parse_template_path
          return nil unless @config.templates

          templates_hash = case @config.templates
                          when Hash
                            @config.templates
                          when String
                            begin
                              YAML.safe_load(@config.templates)
                            rescue StandardError
                              nil
                            end
                          else
                            nil
                          end

          templates_hash&.dig("base_path")
        end

        def determine_default_output
          if @config.output&.single_file&.enabled
            @config.output.single_file.default_filename || "browser.html"
          elsif @config.output&.multi_file&.enabled
            @config.output.multi_file.default_directory || "dist"
          else
            "browser.html"
          end
        end

        def create_data_transformer
          DataTransformer.new(@repository, transformer_options)
        end

        def create_search_builder
          SearchIndexBuilder.new(@repository, search_options)
        end

        def transformer_options
          config_opts = @config.transformation_options || {}
          {
            include_diagrams: config_opts["include_diagrams"] != false,
            format_definitions: config_opts["format_definitions"] != false,
            max_definition_length: config_opts["max_definition_length"],
          }.merge(@options.slice(:include_diagrams, :format_definitions))
        end

        def search_options
          {
            # Pass search configuration to builder
            fields: @config.search&.fields,
            document_types: @config.search&.document_types,
            stop_words: @config.search&.stop_words,
          }
        end

        def default_template_path
          File.join(__dir__, "..", "..", "..", "templates", "static_site")
        end

        def setup_liquid
          Liquid::Template.file_system = Liquid::LocalFileSystem.new(@options[:template_path])
          Liquid::Template.error_mode = :strict
        end

        # Generate single-file SPA
        def generate_single_file
          puts "Generating single-file SPA..."

          # Transform data
          data = @data_transformer.transform
          search_index = @search_builder.build

          # Build context
          context = build_liquid_context(data, search_index, :single_file)

          # Render template
          template_content = File.read(File.join(@options[:template_path],
                                                 "single_file.liquid"))
          template = Liquid::Template.parse(template_content)
          html = template.render(context)

          # Minify if requested
          html = minify_html(html) if @options[:minify]

          # Write output
          File.write(@options[:output], html)
          puts "✓ Generated: #{@options[:output]} (#{File.size(@options[:output]) / 1024}KB)"

          @options[:output]
        end

        # Generate multi-file static site
        def generate_multi_file
          puts "Generating multi-file static site..."

          output_dir = @options[:output]
          FileUtils.mkdir_p(output_dir)
          FileUtils.mkdir_p(File.join(output_dir, "data"))
          FileUtils.mkdir_p(File.join(output_dir, "assets"))

          # Transform data
          data = @data_transformer.transform
          search_index = @search_builder.build

          # Write data files
          write_data_file(File.join(output_dir, "data", "model.json"), data)
          write_data_file(File.join(output_dir, "data", "search.json"),
                          search_index)

          # Build context (without embedded data)
          context = build_liquid_context(nil, nil, :multi_file)

          # Render and write index.html
          template_content = File.read(File.join(@options[:template_path],
                                                 "multi_file.liquid"))
          template = Liquid::Template.parse(template_content)
          html = template.render(context)
          html = minify_html(html) if @options[:minify]
          File.write(File.join(output_dir, "index.html"), html)

          # Copy/generate assets
          generate_assets(output_dir)

          puts "✓ Generated multi-file site in: #{output_dir}"
          output_dir
        end

        def build_liquid_context(data, search_index, mode)
          {
            "config" => {
              "mode" => mode.to_s,
              "title" => @options[:title],
              "description" => @options[:description],
              "theme" => @options[:theme],
              "apiMode" => false, # Static mode by default
            },
            "data" => data,
            "searchIndex" => search_index,
            "buildInfo" => {
              "timestamp" => Time.now.utc.iso8601,
              "generator" => "LutaML Static Site Generator v1.0",
            },
          }
        end

        def write_data_file(path, data)
          json = JSON.pretty_generate(data)
          File.write(path, json)
          puts "  ✓ #{File.basename(path)} (#{File.size(path) / 1024}KB)"
        end

        def generate_assets(output_dir)
          assets_dir = File.join(output_dir, "assets")

          # Generate CSS
          css_content = build_css
          css_path = File.join(assets_dir, "styles.css")
          File.write(css_path, css_content)
          puts "  ✓ styles.css (#{File.size(css_path) / 1024}KB)"

          # Generate JS
          js_content = build_js
          js_path = File.join(assets_dir, "app.js")
          File.write(js_path, js_content)
          puts "  ✓ app.js (#{File.size(js_path) / 1024}KB)"
        end

        def build_css
          # Read CSS modules and concatenate
          css_files = [
            "00-variables.css",
            "01-reset.css",
            "02-base.css",
            "03-layout.css",
            "04-components.css",
            "05-utilities.css",
          ]

          css_parts = css_files.map do |file|
            path = File.join(@options[:template_path], "assets", "styles", file)
            File.exist?(path) ? File.read(path) : ""
          end

          css = css_parts.join("\n\n")
          @options[:minify] ? minify_css(css) : css
        end

        def build_js
          # Read JS modules and concatenate
          js_files = [
            "core/utils.js",
            "core/state.js",
            "core/router.js",
            "search/lunr-custom.js",
            "ui/sidebar.js",
            "ui/details.js",
            "ui/search.js",
            "app.js",
          ]

          js_parts = js_files.map do |file|
            path = File.join(@options[:template_path], "assets", "scripts",
                             file)
            File.exist?(path) ? File.read(path) : ""
          end

          js = js_parts.join("\n\n")
          @options[:minify] ? minify_js(js) : js
        end

        def minify_html(html)
          # Basic HTML minification
          html.gsub(/\s+/, " ")
            .gsub(/>\s+</, "><")
            .strip
        end

        def minify_css(css)
          # Basic CSS minification
          css.gsub(/\s+/, " ")
            .gsub(/\s*{\s*/, "{")
            .gsub(/\s*}\s*/, "}")
            .gsub(/\s*:\s*/, ":")
            .gsub(/\s*;\s*/, ";")
            .strip
        end

        def minify_js(js)
          # Basic JS minification (remove comments and extra whitespace)
          js.gsub(%r{//.*$}, "")       # Remove single-line comments
            .gsub(%r{/\*.*?\*/}m, "")  # Remove multi-line comments
            .gsub(/\s+/, " ")          # Collapse whitespace
            .strip
        end
      end
    end
  end
end
