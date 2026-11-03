# frozen_string_literal: true

require_relative "base_command"
require_relative "../package_tree_formatter"

module Lutaml
  module Xsd
    module Commands
      # Tree command for visualizing LXR package contents
      #
      # Displays package contents in a colorized tree structure with file sizes
      # and categorization. Supports both tree and flat list formats.
      #
      # @example Basic tree view
      #   TreeCommand.new("pkg/urban_function.lxr", {}).run
      #
      # @example With file sizes
      #   TreeCommand.new("pkg/urban_function.lxr", { show_sizes: true }).run
      #
      # @example Flat list without colors
      #   TreeCommand.new("pkg/urban_function.lxr", {
      #     format: "flat",
      #     no_color: true
      #   }).run
      class TreeCommand < BaseCommand
        attr_reader :package_path

        # Initialize tree command
        #
        # @param package_path [String] Path to .lxr package file
        # @param options [Hash] Command options
        # @option options [Boolean] :show_sizes Show file sizes
        # @option options [Boolean] :no_color Disable colored output
        # @option options [String] :format Output format (tree or flat)
        def initialize(package_path, options = {})
          super(options)
          @package_path = package_path
        end

        # Execute the tree command
        #
        # @return [void]
        def run
          validate_package_file
          display_tree
        rescue StandardError => e
          handle_error(e)
        end

        private

        # Validate package file exists
        #
        # @return [void]
        # @raise [SystemExit] If package file not found
        def validate_package_file
          return if File.exist?(package_path)

          raise Lutaml::Xsd::Error, "Package file not found: #{package_path}"
        end

        # Display package tree
        #
        # @return [void]
        def display_tree
          verbose_output "Loading package: #{package_path}"

          formatter = create_formatter
          tree_output = formatter.format

          output tree_output

          verbose_output "✓ Tree display complete"
        end

        # Create tree formatter instance
        #
        # @return [PackageTreeFormatter] Configured formatter
        def create_formatter
          PackageTreeFormatter.new(
            package_path,
            show_sizes: options[:show_sizes] || false,
            no_color: options[:no_color] || false,
            format: parse_format_option,
          )
        end

        # Parse format option
        #
        # @return [Symbol] Format as symbol (:tree or :flat)
        def parse_format_option
          format_str = options[:format] || "tree"
          format_str.to_sym
        end

        # Handle command errors
        #
        # @param error [StandardError] Error to handle
        # @return [void]
        def handle_error(error)
          error_msg = case error
                      when Zip::Error
                        "Failed to read package file: #{error.message}"
                      when Lutaml::Xsd::Error
                        "Package error: #{error.message}"
                      else
                        "Failed to display tree: #{error.message}"
                      end
          error error_msg
          verbose_output error.backtrace.join("\n") if verbose?
          raise error
        end
      end
    end
  end
end
