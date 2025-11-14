# frozen_string_literal: true

require_relative "../model_transformations"
require_relative "repository"

module Lutaml
  module UmlRepository
    # Enhanced Repository with unified model transformation support.
    #
    # This class extends the original Repository to support the new
    # unified model transformation system, providing seamless integration
    # with XMI, QEA, and future format parsers.
    #
    # The enhanced repository follows SOLID principles and provides
    # backward compatibility with existing code while enabling new
    # transformation capabilities.
    #
    # @example Enhanced XMI parsing
    #   repo = RepositoryEnhanced.from_model("model.xmi")
    #
    # @example Enhanced QEA parsing
    #   repo = RepositoryEnhanced.from_model("model.qea")
    #
    # @example With custom configuration
    #   config = ModelTransformations::Configuration.load("my_config.yml")
    #   repo = RepositoryEnhanced.from_model("model.qea", config: config)
    class RepositoryEnhanced < Repository
      # @return [ModelTransformations::TransformationEngine] The transformation engine
      attr_reader :transformation_engine

      # @return [Hash] Transformation metadata
      attr_reader :transformation_metadata

      # Initialize enhanced repository
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @param indexes [Hash, nil] Pre-built indexes
      # @param transformation_engine [ModelTransformations::TransformationEngine, nil] Custom engine
      # @param transformation_metadata [Hash] Metadata from transformation process
      def initialize(document:, indexes: nil, transformation_engine: nil,
transformation_metadata: {})
        super(document: document, indexes: indexes)

        @transformation_engine = transformation_engine || ModelTransformations.engine
        @transformation_metadata = transformation_metadata.freeze
      end

      # Build enhanced repository from any supported model format
      #
      # This method auto-detects the format and uses the appropriate parser
      # from the unified transformation system.
      #
      # @param model_path [String] Path to the model file
      # @param options [Hash] Parsing and repository options
      # @option options [ModelTransformations::Configuration] :config Custom configuration
      # @option options [Boolean] :validate Validate model after parsing
      # @option options [Boolean] :lazy Enable lazy loading
      # @option options [Symbol] :preset Use configuration preset (:fast, :comprehensive, :production)
      # @return [RepositoryEnhanced] Enhanced repository instance
      def self.from_model(model_path, options = {})
        # Setup transformation engine with custom config if provided
        engine = setup_transformation_engine(options)

        # Apply preset if specified
        apply_preset(engine, options[:preset]) if options[:preset]

        # Parse model using unified transformation system
        document = engine.parse(model_path, extract_parsing_options(options))

        # Build indexes
        indexes = options[:lazy] ? nil : IndexBuilder.build_all(document)

        # Create enhanced repository
        enhanced_repo = new(
          document: document,
          indexes: indexes,
          transformation_engine: engine,
          transformation_metadata: extract_transformation_metadata(engine,
                                                                   model_path),
        )

        # Validate if requested
        enhanced_repo.validate if options[:validate]

        enhanced_repo
      end

      # Build enhanced repository from XMI with legacy compatibility
      #
      # This method provides backward compatibility with the original from_xmi
      # method while using the new transformation system internally.
      #
      # @param xmi_path [String] Path to XMI file
      # @param options [Hash] Options for parsing
      # @return [RepositoryEnhanced] Enhanced repository instance
      def self.from_xmi_enhanced(xmi_path, options = {})
        from_model(xmi_path, options.merge(format_hint: :xmi))
      end

      # Build enhanced repository from QEA
      #
      # @param qea_path [String] Path to QEA file
      # @param options [Hash] Options for parsing
      # @return [RepositoryEnhanced] Enhanced repository instance
      def self.from_qea_enhanced(qea_path, options = {})
        from_model(qea_path, options.merge(format_hint: :qea))
      end

      # Auto-detect and load from file with enhanced capabilities
      #
      # @param file_path [String] Path to model file
      # @param options [Hash] Loading options
      # @return [RepositoryEnhanced] Enhanced repository instance
      def self.from_file_enhanced(file_path, options = {})
        from_model(file_path, options)
      end

      # Load from LUR package with transformation metadata
      #
      # @param lur_path [String] Path to LUR package
      # @param options [Hash] Loading options
      # @return [RepositoryEnhanced] Enhanced repository instance
      def self.from_package_enhanced(lur_path, _options = {})
        # Load using original method but wrap in enhanced repository
        original_repo = from_package(lur_path)

        new(
          document: original_repo.document,
          indexes: original_repo.indexes,
          transformation_metadata: {
            source_file: lur_path,
            source_format: "LUR Package",
            loaded_at: Time.now,
            loader: "Enhanced Package Loader",
          },
        )
      end

      # Get transformation statistics and metadata
      #
      # @return [Hash] Comprehensive transformation information
      def transformation_info
        base_info = {
          source_file: @transformation_metadata[:source_file],
          source_format: @transformation_metadata[:source_format],
          parsed_at: @transformation_metadata[:parsed_at],
          parser: @transformation_metadata[:parser],
          transformation_engine: @transformation_engine.class.name,
        }

        # Add engine statistics if available
        if @transformation_engine.respond_to?(:statistics)
          base_info[:engine_statistics] = @transformation_engine.statistics
        end

        base_info
      end

      # Get parsing history for the source file
      #
      # @return [Array<Hash>] Parsing history entries
      def parsing_history
        source_file = @transformation_metadata[:source_file]
        return [] unless source_file

        @transformation_engine.history_for_file(source_file)
      end

      # Check if repository supports a file format
      #
      # @param file_path [String] Path to check
      # @return [Boolean] true if format is supported
      def self.supports_file?(file_path)
        ModelTransformations.engine.supports_file?(file_path)
      end

      # Get list of supported file extensions
      #
      # @return [Array<String>] Supported extensions
      def self.supported_extensions
        ModelTransformations.engine.supported_extensions
      end

      # Detect format for a file
      #
      # @param file_path [String] Path to analyze
      # @return [String, nil] Detected format name or nil
      def self.detect_format(file_path)
        parser_class = ModelTransformations.engine.detect_parser(file_path)
        return nil unless parser_class

        # Create temporary instance to get format name
        temp_parser = parser_class.new
        temp_parser.format_name
      rescue StandardError
        nil
      end

      # Export with enhanced metadata
      #
      # @param output_path [String] Path for output file
      # @param options [Hash] Export options
      # @return [void]
      def export_to_package_enhanced(output_path, options = {})
        # Include transformation metadata in export
        enhanced_options = options.merge(
          transformation_metadata: @transformation_metadata,
          engine_info: {
            engine_class: @transformation_engine.class.name,
            supported_formats: @transformation_engine.supported_extensions,
            configuration_version: @transformation_engine.configuration.version,
          },
        )

        export_to_package(output_path, enhanced_options)
      end

      # Validate with enhanced error reporting
      #
      # @return [Hash] Enhanced validation results
      def validate_enhanced
        base_validation = validate

        # Add transformation-specific validation
        transformation_validation = validate_transformation_quality

        {
          base_validation: base_validation,
          transformation_validation: transformation_validation,
          overall_valid: base_validation.valid? && transformation_validation[:valid],
          recommendations: generate_recommendations(base_validation,
                                                    transformation_validation),
        }
      end

      # Get comprehensive statistics including transformation info
      #
      # @return [Hash] Enhanced statistics
      def statistics_enhanced
        base_stats = statistics

        transformation_stats = {
          source_format: @transformation_metadata[:source_format],
          parsing_duration: @transformation_metadata[:parsing_duration],
          parser_used: @transformation_metadata[:parser],
          transformation_warnings: @transformation_metadata[:warnings]&.size || 0,
          transformation_errors: @transformation_metadata[:errors]&.size || 0,
        }

        base_stats.merge(transformation_stats: transformation_stats)
      end

      # Register custom parser with the transformation engine
      #
      # @param extension [String] File extension
      # @param parser_class [Class] Parser class
      # @return [void]
      def register_parser(extension, parser_class)
        @transformation_engine.register_parser(extension, parser_class)
      end

      # Update transformation engine configuration
      #
      # @param config [ModelTransformations::Configuration] New configuration
      # @return [void]
      def update_configuration(config)
        @transformation_engine.configuration = config
      end

      private

      # Setup transformation engine with custom configuration
      #
      # @param options [Hash] Setup options
      # @return [ModelTransformations::TransformationEngine] Configured engine
      def self.setup_transformation_engine(options)
        if options[:config]
          ModelTransformations::TransformationEngine.new(options[:config])
        else
          ModelTransformations.engine
        end
      end

      # Apply configuration preset
      #
      # @param engine [ModelTransformations::TransformationEngine] Engine to configure
      # @param preset [Symbol] Preset name
      # @return [void]
      def self.apply_preset(_engine, preset)
        # This would apply preset configurations from the YAML config
        # For now, this is a placeholder for future implementation
        case preset
        when :fast
          # Apply fast parsing settings
        when :comprehensive
          # Apply comprehensive parsing settings
        when :production
          # Apply production settings
        end
      end

      # Extract parsing options from repository options
      #
      # @param options [Hash] Repository options
      # @return [Hash] Parsing options
      def self.extract_parsing_options(options)
        parsing_options = {}

        # Map repository options to parsing options
        if options.key?(:validate)
          parsing_options[:validate_output] =
            options[:validate]
        end
        if options.key?(:include_diagrams)
          parsing_options[:include_diagrams] =
            options[:include_diagrams]
        end
        if options.key?(:resolve_references)
          parsing_options[:resolve_references] =
            options[:resolve_references]
        end

        parsing_options
      end

      # Extract transformation metadata from engine
      #
      # @param engine [ModelTransformations::TransformationEngine] Transformation engine
      # @param file_path [String] Source file path
      # @return [Hash] Transformation metadata
      def self.extract_transformation_metadata(engine, file_path)
        # Get the most recent transformation for this file
        history = engine.history_for_file(file_path)
        latest = history.last

        if latest
          {
            source_file: file_path,
            source_format: latest[:parser]&.format_name,
            parsed_at: latest[:timestamp],
            parser: latest[:parser]&.class&.name,
            parsing_duration: latest[:duration],
            success: latest[:success],
            warnings: latest[:parser]&.warnings || [],
            errors: latest[:parser]&.errors || [],
          }
        else
          {
            source_file: file_path,
            parsed_at: Time.now,
          }
        end
      end

      # Validate transformation quality
      #
      # @return [Hash] Transformation validation results
      def validate_transformation_quality
        results = {
          valid: true,
          warnings: [],
          errors: [],
          quality_score: 100.0,
        }

        # Check for transformation warnings
        if @transformation_metadata[:warnings]&.any?
          results[:warnings].concat(@transformation_metadata[:warnings])
          results[:quality_score] -= @transformation_metadata[:warnings].size * 5
        end

        # Check for transformation errors
        if @transformation_metadata[:errors]&.any?
          results[:errors].concat(@transformation_metadata[:errors])
          results[:quality_score] -= @transformation_metadata[:errors].size * 10
          results[:valid] = false if @transformation_metadata[:errors].size > 5
        end

        # Check parsing duration
        if @transformation_metadata[:parsing_duration] && (@transformation_metadata[:parsing_duration] > 60) # More than 1 minute
          results[:warnings] << "Long parsing duration (#{@transformation_metadata[:parsing_duration].round(2)}s)"
          results[:quality_score] -= 5
        end

        results[:quality_score] = [results[:quality_score], 0].max
        results
      end

      # Generate recommendations based on validation results
      #
      # @param base_validation [Object] Base validation results
      # @param transformation_validation [Hash] Transformation validation results
      # @return [Array<String>] Recommendations
      def generate_recommendations(base_validation, transformation_validation)
        recommendations = []

        # Base validation recommendations
        unless base_validation.valid?
          recommendations << "Address model validation errors for better reliability"
        end

        # Transformation-specific recommendations
        if transformation_validation[:errors].any?
          recommendations << "Review transformation errors to ensure data completeness"
        end

        if transformation_validation[:warnings].size > 10
          recommendations << "Consider using a different parser or format for better results"
        end

        if transformation_validation[:quality_score] < 80
          recommendations << "Model quality is below recommended threshold, review source file"
        end

        recommendations
      end
    end
  end
end
