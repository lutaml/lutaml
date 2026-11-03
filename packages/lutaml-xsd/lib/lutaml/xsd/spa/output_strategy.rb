# frozen_string_literal: true

require "fileutils"

module Lutaml
  module Xsd
    module Spa
      # Base class for output strategies (Strategy Pattern)
      #
      # Defines the interface for different output modes (single-file vs
      # multi-file). Subclasses implement specific strategies for writing
      # generated documentation to the filesystem.
      #
      # This implements the Template Method pattern where the overall algorithm
      # is defined in the base class, but specific steps are implemented by
      # subclasses.
      #
      # @abstract Subclass and implement {#write_files} to create a concrete
      #   output strategy
      #
      # @example Using an output strategy
      #   strategy = SingleFileStrategy.new(output_path: 'docs.html')
      #   files = strategy.write(html_content, schema_data)
      #   puts "Generated files: #{files.join(', ')}"
      class OutputStrategy
        attr_reader :verbose

        # Initialize output strategy
        #
        # @param verbose [Boolean] Enable verbose output
        def initialize(verbose: false)
          @verbose = verbose
        end

        # Write output files (template method)
        #
        # This method defines the algorithm for writing output files:
        # 1. Prepare output directory
        # 2. Write files using strategy-specific implementation
        # 3. Verify written files
        # 4. Return list of written files
        #
        # @param html_content [String] Generated HTML content
        # @param schema_data [Hash] Serialized schema data
        # @return [Array<String>] List of written file paths
        def write(html_content, schema_data)
          log "Preparing output using #{self.class.name}..."

          prepare_output
          files = write_files(html_content, schema_data)
          verify_files(files)

          log "✓ Successfully wrote #{files.size} file(s)"
          files
        end

        protected

        # Prepare output directory (template method hook)
        #
        # Subclasses can override this to customize directory preparation.
        # Default implementation does nothing.
        #
        # @return [void]
        def prepare_output
          # Default: no preparation needed
        end

        # Write files using strategy-specific implementation
        #
        # @abstract Subclasses must implement this method
        # @param html_content [String] Generated HTML content
        # @param schema_data [Hash] Serialized schema data
        # @return [Array<String>] List of written file paths
        # @raise [NotImplementedError] if not implemented by subclass
        def write_files(_html_content, _schema_data)
          raise NotImplementedError,
                "#{self.class.name} must implement #write_files"
        end

        # Verify that files were written successfully
        #
        # @param files [Array<String>] List of file paths to verify
        # @return [void]
        # @raise [IOError] if any file is missing or empty
        def verify_files(files)
          files.each do |file_path|
            unless File.exist?(file_path)
              raise IOError, "Failed to write file: #{file_path}"
            end

            if File.empty?(file_path)
              raise IOError, "File is empty: #{file_path}"
            end
          end
        end

        # Ensure directory exists
        #
        # @param path [String] Directory path
        # @return [void]
        def ensure_directory(path)
          return if Dir.exist?(path)

          FileUtils.mkdir_p(path)
          log "✓ Created directory: #{path}"
        end

        # Write file to disk
        #
        # @param path [String] File path
        # @param content [String] File content
        # @return [String] File path that was written
        def write_file(path, content)
          content ||= "" # Handle nil content
          File.write(path, content)
          log "✓ Wrote: #{path} (#{format_size(content.bytesize)})"
          path
        end

        # Format byte size for display
        #
        # @param bytes [Integer] Size in bytes
        # @return [String] Formatted size (e.g., "1.5 KB")
        def format_size(bytes)
          if bytes < 1024
            "#{bytes} B"
          elsif bytes < 1024 * 1024
            "#{(bytes / 1024.0).round(1)} KB"
          else
            "#{(bytes / (1024.0 * 1024.0)).round(1)} MB"
          end
        end

        # Log message if verbose mode enabled
        #
        # @param message [String] Message to log
        # @return [void]
        def log(message)
          puts message if verbose
        end
      end
    end
  end
end
