# frozen_string_literal: true

require "json"

module Lutaml
  module UmlRepository
    module StaticSite
      # Orchestrates static site generation.
      #
      # Thin coordinator that delegates to:
      # - DataTransformer for building the typed SpaDocument
      # - SearchIndexBuilder for building the typed SpaSearchIndex
      # - Output::Strategy subclass for rendering HTML
      #
      # @example Single-file Vue IIFE output
      #   generator = Generator.new(repository,
      #     output_strategy: Output::VueInlinedStrategy,
      #     output: "browser.html")
      #   generator.generate
      class Generator
        attr_reader :repository, :config, :options, :id_generator,
                    :data_transformer, :search_builder

        def initialize(repository, options = {})
          @repository = repository
          @config = options[:config] ||
            Configuration.load(options[:config_path])
          @options = build_options(options)

          @id_generator = options[:id_generator] || IdGenerator.new
          @data_transformer = options[:data_transformer] ||
            create_data_transformer
          @search_builder = options[:search_builder] ||
            create_search_builder

          @output_strategy = resolve_strategy(options)
        end

        def generate
          spa_document = @data_transformer.transform
          search_index = @search_builder.build

          @output_strategy.render(spa_document, search_index)
        end

        private

        def build_options(user_options)
          defaults = {
            mode: :single_file,
            output: determine_default_output,
          }

          config_options = {
            title: @config.ui&.title,
            description: @config.ui&.description,
          }.compact

          defaults.merge(config_options).merge(user_options)
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

        def resolve_strategy(options)
          strategy_class = options[:output_strategy]
          if strategy_class
            return strategy_class.new(@options[:output],
                                      config: @config)
          end

          case @options[:mode]
          when :single_file
            Output::VueInlinedStrategy.new(@options[:output], config: @config)
          when :multi_file
            Output::MultiFileStrategy.new(@options[:output], config: @config)
          else
            raise ArgumentError,
                  "Invalid mode: #{@options[:mode]}. " \
                  "Use :single_file or :multi_file"
          end
        end

        def create_data_transformer
          DataTransformer.new(@repository,
                              transformer_options.merge(config: @config))
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
          }.merge(@options.slice(:include_diagrams, :format_definitions,
                                 :render_diagrams))
        end

        def search_options
          {
            fields: @config.search&.fields,
            document_types: @config.search&.document_types,
            stop_words: @config.search&.stop_words,
          }
        end
      end
    end
  end
end
