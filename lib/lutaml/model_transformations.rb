# frozen_string_literal: true

module Lutaml
  # Model Transformations module provides a unified, extensible system for
  # transforming various UML model formats (XMI, QEA, etc.) into a common
  # UML document representation.
  #
  # This module follows SOLID principles and implements:
  # - Single Responsibility: Each component has one clear purpose
  # - Open/Closed: Easy to extend with new formats without modifying existing code
  # - Liskov Substitution: All parsers implement the same interface
  # - Interface Segregation: Clients depend only on methods they use
  # - Dependency Inversion: Depends on abstractions, not concrete implementations
  #
  # @example Parse any supported format
  #   engine = Lutaml::ModelTransformations::TransformationEngine.new
  #   document = engine.parse("model.xmi")
  #   document = engine.parse("model.qea")
  #
  # @example Register custom parser
  #   engine.register_parser(".custom", MyCustomParser)
  #   document = engine.parse("model.custom")
  #
  # @example Use custom configuration
  #   config = Lutaml::ModelTransformations::Configuration.load("my_config.yml")
  #   engine = Lutaml::ModelTransformations::TransformationEngine.new(config)
  module ModelTransformations
    # Core components
    autoload :Configuration, "lutaml/model_transformations/configuration"
    autoload :FormatRegistry, "lutaml/model_transformations/format_registry"
    autoload :TransformationEngine,
             "lutaml/model_transformations/transformation_engine"

    # Parsers
    module Parsers
      autoload :BaseParser, "lutaml/model_transformations/parsers/base_parser"
      autoload :XmiParser, "lutaml/model_transformations/parsers/xmi_parser"
      autoload :QeaParser, "lutaml/model_transformations/parsers/qea_parser"
    end
    class << self
      # Get the default transformation engine
      #
      # @return [TransformationEngine] The default engine instance
      def engine
        @engine ||= TransformationEngine.new
      end

      # Set a custom transformation engine
      #
      # @param engine [TransformationEngine] The engine to use
      def engine=(engine)
        @engine = engine
      end

      # Parse a model file using the default engine
      #
      # @param file_path [String] Path to the model file
      # @param options [Hash] Parsing options
      # @return [Lutaml::Uml::Document] The parsed UML document
      def parse(file_path, options = {})
        engine.parse(file_path, options)
      end

      # Auto-detect file format and return appropriate parser
      #
      # @param file_path [String] Path to the model file
      # @return [Class] The parser class for the file format
      def detect_parser(file_path)
        engine.detect_parser(file_path)
      end

      # Get list of supported file extensions
      #
      # @return [Array<String>] List of supported extensions
      def supported_extensions
        engine.supported_extensions
      end

      # Register a custom parser for a file extension
      #
      # @param extension [String] File extension (e.g., ".custom")
      # @param parser_class [Class] Parser class implementing BaseParser interface
      def register_parser(extension, parser_class)
        engine.register_parser(extension, parser_class)
      end

      # Load configuration from file
      #
      # @param config_path [String] Path to configuration file
      # @return [Configuration] The loaded configuration
      def load_configuration(config_path)
        Configuration.load(config_path)
      end

      # Get current configuration
      #
      # @return [Configuration] The current configuration
      def configuration
        engine.configuration
      end

      # Set configuration
      #
      # @param config [Configuration] The configuration to use
      def configuration=(config)
        engine.configuration = config
      end
    end
  end
end
