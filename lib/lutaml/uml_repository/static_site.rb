# frozen_string_literal: true

module Lutaml
  module UmlRepository
    # Static Site generation for UML model browsing.
    #
    # Generates a single-page application (SPA) from typed UML models:
    # - Vue 3 + Pinia + TypeScript frontend (pre-built IIFE)
    # - lunr.js for client-side search
    # - Strategy pattern for output (single-file or multi-file)
    # - Full typed data layer via Lutaml::Model::Serializable
    #
    # @example Generate single-file SPA
    #   repository = UmlRepository.from_package("model.lur")
    #   Lutaml::Xmi::StaticSite.generate(repository,
    #     mode: :single_file,
    #     output: "browser.html"
    #   )
    #
    # @example Generate with custom configuration
    #   config = Lutaml::Xmi::StaticSite::Configuration.load("custom.yml")
    #   Lutaml::Xmi::StaticSite.generate(repository,
    #     config: config,
    #     mode: :multi_file,
    #     output: "dist/"
    #   )
    module StaticSite
      autoload :Configuration, "lutaml/uml_repository/static_site/configuration"
      autoload :IdGenerator, "lutaml/uml_repository/static_site/id_generator"
      autoload :DataTransformer,
               "lutaml/uml_repository/static_site/data_transformer"
      autoload :SearchIndexBuilder,
               "lutaml/uml_repository/static_site/search_index_builder"
      autoload :Generator, "lutaml/uml_repository/static_site/generator"
      autoload :Models, "lutaml/uml_repository/static_site/models"
      autoload :Serializers, "lutaml/uml_repository/static_site/serializers"
      autoload :Output, "lutaml/uml_repository/static_site/output"

      class << self
        # Generate a static site from a repository
        #
        # @param repository [UmlRepository] The repository to generate from
        # @param options [Hash] Generation options
        # @option options [Configuration] :config Configuration instance
        # @option options [Symbol] :mode Output mode
        # (:single_file or :multi_file)
        # @option options [String] :output Output path
        # @return [String] Path to generated output
        def generate(repository, options = {})
          generator = Generator.new(repository, options)
          generator.generate
        end

        # Transform repository data to JSON
        #
        # @param repository [UmlRepository] The repository to transform
        # @param options [Hash] Transformation options
        # @return [Hash] JSON data structure
        def transform_data(repository, options = {})
          config = options[:config] || Configuration.load
          transformer_opts = config.transformation_options.merge(options)
          transformer = DataTransformer.new(repository, transformer_opts)
          transformer.transform
        end

        # Build search index from repository
        #
        # @param repository [UmlRepository] The repository to index
        # @param options [Hash] Index options
        # @return [Hash] Search index structure
        def build_search_index(repository, options = {})
          config = options[:config] || Configuration.load
          search_opts = {
            fields: config.search&.fields,
            document_types: config.search&.document_types,
            stop_words: config.search&.stop_words,
          }.merge(options)
          builder = SearchIndexBuilder.new(repository, search_opts)
          builder.build
        end

        # Load configuration
        #
        # @param config_path [String, nil] Path to config file
        # @return [Configuration] Loaded configuration
        def configuration(config_path = nil)
          Configuration.load(config_path)
        end
      end
    end
  end
end
