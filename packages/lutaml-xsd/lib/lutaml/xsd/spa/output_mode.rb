# frozen_string_literal: true

require "fileutils"

module Lutaml
  module Xsd
    module Spa
      # Handles different output modes for SPA documentation
      #
      # Supports single-file (embedded) and multi-file (distributed)
      # output modes with appropriate file organization.
      class OutputMode
        # Create output mode handler
        #
        # @param mode [String] Output mode ('single' or 'multi')
        # @param output_path [String, nil] Output file path (single mode)
        # @param output_dir [String, nil] Output directory (multi mode)
        # @param verbose [Boolean] Enable verbose output
        # @return [OutputMode] Output mode handler
        def self.create(mode:, output_path: nil, output_dir: nil,
verbose: false)
          case mode
          when "single"
            SingleFileMode.new(output_path, verbose)
          when "multi"
            MultiFileMode.new(output_dir, verbose)
          else
            raise ArgumentError, "Invalid mode: #{mode}"
          end
        end
      end

      # Single-file output mode
      class SingleFileMode
        attr_reader :output_path, :verbose

        def initialize(output_path, verbose = false)
          @output_path = output_path
          @verbose = verbose
        end

        # Write single HTML file with embedded resources
        #
        # @param html_content [String] Complete HTML content
        # @param _schema_data [Hash] Schema data (unused in single mode)
        # @return [Array<String>] List of written files
        def write(html_content, _schema_data)
          # Ensure output directory exists
          output_dir = File.dirname(output_path)
          FileUtils.mkdir_p(output_dir)

          # Write HTML file
          File.write(output_path, html_content)
          log "✓ Wrote: #{output_path}"

          [output_path]
        end

        private

        def log(message)
          puts message if verbose
        end
      end

      # Multi-file output mode
      class MultiFileMode
        attr_reader :output_dir, :verbose

        def initialize(output_dir, verbose = false)
          @output_dir = output_dir
          @verbose = verbose
        end

        # Write multiple files with external resources
        #
        # @param html_content [String] HTML content
        # @param schema_data [Hash] Schema data
        # @return [Array<String>] List of written files
        def write(html_content, schema_data)
          # Ensure output directory structure exists
          FileUtils.mkdir_p(output_dir)
          FileUtils.mkdir_p(File.join(output_dir, "data"))
          FileUtils.mkdir_p(File.join(output_dir, "js"))
          FileUtils.mkdir_p(File.join(output_dir, "css"))

          written_files = []

          # Write HTML file
          html_path = File.join(output_dir, "index.html")
          File.write(html_path, html_content)
          log "✓ Wrote: #{html_path}"
          written_files << html_path

          # Write JSON data file
          json_path = File.join(output_dir, "data", "schemas.json")
          File.write(json_path, JSON.pretty_generate(schema_data))
          log "✓ Wrote: #{json_path}"
          written_files << json_path

          # NOTE: JS and CSS files would be written here in a complete implementation
          # For now, they're embedded in the HTML

          written_files
        end

        private

        def log(message)
          puts message if verbose
        end
      end
    end
  end
end
