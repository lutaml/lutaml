# frozen_string_literal: true

require_relative "../output_formatter"

module Lutaml
  module Cli
    module Commands
      # BaseCommand provides common functionality for all command handlers
      #
      # All command classes should inherit from this base class to access
      # common utilities like repository loading, error handling,
      # and output formatting.
      class BaseCommand
        attr_reader :repository, :options

        # Initialize command with repository and options
        #
        # @param repository [Lutaml::UmlRepository::Repository, nil]
        # Repository instance
        # @param options [Hash] Command options
        def initialize(repository = nil, options = {})
          @repository = repository
          @options = options
        end

        # Execute the command (to be implemented by subclasses)
        #
        # @raise [NotImplementedError] If not overridden by subclass
        def execute
          raise NotImplementedError,
                "#{self.class.name} must implement #execute"
        end

        protected

        # Load repository from LUR file
        #
        # @param lur_path [String] Path to LUR package file
        # @param lazy [Boolean] Whether to use lazy loading
        # @return [Lutaml::UmlRepository::Repository] Loaded repository
        def load_repository(lur_path, lazy: false) # rubocop:disable Metrics/MethodLength
          unless File.exist?(lur_path)
            error_and_exit("Package file not found: #{lur_path}")
          end

          OutputFormatter.progress("Loading repository from #{lur_path}")
          require_relative "../../uml_repository/repository"
          repo = if lazy
                   Lutaml::UmlRepository::Repository.from_package_lazy(lur_path)
                 else
                   Lutaml::UmlRepository::Repository.from_package(lur_path)
                 end
          OutputFormatter.progress_done
          repo
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          error_and_exit("Failed to load repository: #{e.message}")
        end

        # Normalize path syntax
        #
        # Converts :: or <RepositoryRoot>:: to ModelRoot
        #
        # @param path [String, nil] Path to normalize
        # @return [String] Normalized path
        def normalize_path(path)
          return "ModelRoot" if path.nil? || path.empty?
          return "ModelRoot" if ["::", "<RepositoryRoot>"].include?(path)

          # Convert leading :: to ModelRoot::
          path = path.sub(/^::/, "ModelRoot::")
          # Convert <RepositoryRoot>:: to ModelRoot::
          path.sub(/^<RepositoryRoot>::/, "ModelRoot::")
        end

        # Print error message and exit
        #
        # @param message [String] Error message
        # @param code [Integer] Exit code (default: 1)
        def error_and_exit(message, code: 1)
          puts OutputFormatter.error(message)
          exit code
        end

        # Print warning message
        #
        # @param message [String] Warning message
        def warn(message)
          puts OutputFormatter.warning(message)
        end

        # Print success message
        #
        # @param message [String] Success message
        def success(message)
          puts OutputFormatter.success(message)
        end

        # Print info message
        #
        # @param message [String] Info message
        def info(message)
          puts OutputFormatter.info(message)
        end

        # Format and print output based on format option
        #
        # @param data [Object] Data to format
        # @param format [String, nil] Output format
        # (uses options[:format] if nil)
        def print_formatted(data, format: nil)
          format ||= options[:format] || "text"
          puts OutputFormatter.format(data, format: format)
        end
      end
    end
  end
end
