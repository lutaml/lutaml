# frozen_string_literal: true

require_relative "configuration_loader"
require_relative "schema_serializer"
require_relative "strategies/vue_inlined_strategy"
require_relative "strategies/vue_cdn_strategy"

module Lutaml
  module Xsd
    module Spa
      # Main SPA documentation generator
      #
      # Generates interactive HTML Single Page Application documentation
      # from XSD schemas using Vue.js frontend.
      #
      # @example Generate single-file SPA
      #   generator = Generator.new(
      #     package,
      #     'output/docs.html',
      #     mode: 'inlined'
      #   )
      #   generator.generate
      class Generator
        attr_reader :package, :output_path, :options

        # Initialize SPA generator
        #
        # @param package [SchemaRepositoryPackage] Schema repository package
        # @param output_path [String] Output file path
        # @param options [Hash] Generation options
        # @option options [String] :mode Output mode ('inlined' or 'cdn')
        # @option options [Boolean] :verbose Enable verbose output
        def initialize(package, output_path, options = {})
          @package = package
          @output_path = output_path
          @options = options
          @config_loader = ConfigurationLoader.new
          @serializer = SchemaSerializer.new(package)
        end

        # Generate SPA documentation
        #
        # @return [Array<String>] List of generated file paths
        def generate
          log "Starting SPA generation..."

          # Create output strategy
          strategy = create_strategy
          mode = options[:mode] || "inlined"
          strategy_name = "#{mode.split('_').map(&:capitalize).join(' ')} Strategy"
          log "✓ Using #{strategy_name}"

          # Serialize schema data
          serialized_data = @serializer.serialize
          log "✓ Serialized #{serialized_data[:schemas]&.size || 0} schema(s)"

          # Generate output using strategy
          output_files = strategy.generate(serialized_data, nil)
          log "✓ Generated #{output_files&.size || 0} file(s)"

          output_files
        end

        private

        # Create appropriate output strategy based on mode
        #
        # @return [OutputStrategy] Strategy instance
        def create_strategy
          mode = options[:mode] || "inlined"

          case mode
          when "inlined"
            Strategies::VueInlinedStrategy.new(
              output_path,
              @config_loader,
              verbose: verbose?,
            )
          when "cdn"
            Strategies::VueCdnStrategy.new(
              output_path,
              @config_loader,
              verbose: verbose?,
            )
          else
            raise ArgumentError,
                  "Unknown mode: #{mode}. Valid modes: inlined, cdn"
          end
        end

        # Check if verbose mode is enabled
        #
        # @return [Boolean] True if verbose
        def verbose?
          options[:verbose] == true
        end

        # Log message if verbose mode is enabled
        #
        # @param message [String] Message to log
        # @return [void]
        def log(message)
          puts message if verbose?
        end
      end
    end
  end
end
