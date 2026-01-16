# frozen_string_literal: true

require "yaml"
require "json"
require "table_tennis"

module Lutaml
  module Cli
    # OutputFormatter provides formatting utilities for CLI output
    #
    # Supports multiple output formats:
    # - text: Human-readable text format
    # - table: Tabular format for structured data
    # - yaml: YAML format
    # - json: JSON format
    # - tree: Tree view for hierarchical data
    class OutputFormatter
      # ANSI color codes for terminal output
      COLORS = {
        red: "\e[31m",
        green: "\e[32m",
        yellow: "\e[33m",
        blue: "\e[34m",
        magenta: "\e[35m",
        cyan: "\e[36m",
        reset: "\e[0m",
      }.freeze

      # Format and output data based on the specified format
      #
      # @param data [Object] Data to format
      # @param format [String] Output format (text, yaml, json, table)
      # @return [String] Formatted output
      def self.format(data, format: "text") # rubocop:disable Metrics/MethodLength
        case format.to_s.downcase
        when "yaml"
          # Convert to plain hash if needed for proper YAML serialization
          plain_data = convert_to_plain_hash(data)
          plain_data.to_yaml
        when "json"
          # Convert to plain hash for proper JSON serialization
          plain_data = convert_to_plain_hash(data)
          JSON.pretty_generate(plain_data)
        when "table"
          format_table(data)
        when "text"
          format_text(data)
        else
          data.to_s
        end
      end

      # Convert data to a plain Ruby hash for serialization.
      #
      # @param data [Object] Data to convert
      # @return [Hash] Plain Ruby hash
      def self.convert_to_plain_hash(data) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
        return data unless data

        case data
        when Hash
          # Deep convert to plain hash
          data.transform_values do |value|
            convert_to_plain_hash(value)
          end
        when Array
          data.map { |item| convert_to_plain_hash(item) }
        when String, Integer, Float, TrueClass, FalseClass, NilClass
          data
        else
          # For complex objects, convert to string representation
          data.respond_to?(:name) ? data.name : data.to_s
        end
      end

      # Format data as a simple table
      #
      # @param data [Hash, Array] Data to format
      # @return [String] Formatted table
      def self.format_table(data)
        return "" if data.nil? || data.empty?

        if data.is_a?(Hash)
          format_hash_table(data)
        elsif data.is_a?(Array) && data.first.is_a?(Hash)
          format_array_table(data)
        else
          data.to_s
        end
      end

      # Format a hash as a two-column table
      #
      # @param hash [Hash] Hash to format
      # @return [String] Formatted table
      def self.format_hash_table(hash) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        max_key_length = hash.keys.map(&:to_s).map(&:length).max || 0
        lines = []

        hash.each do |key, value|
          formatted_value = if value.is_a?(Hash) || value.is_a?(Array)
                              value.inspect
                            else
                              value.to_s
                            end
          lines << format("%-#{max_key_length}s : %s", key, formatted_value)
        end

        lines.join("\n")
      end

      # Format an array of hashes as a table using TableTennis
      #
      # @param array [Array<Hash>] Array to format
      # @param options [Hash] TableTennis options
      # @return [String] Formatted table
      def self.format_array_table(array, options: {}) # rubocop:disable Metrics/MethodLength
        return "" if array.empty?

        # Default TableTennis options for lutaml
        # Set layout: false to prevent aggressive column shrinking
        default_options = {
          zebra: true,
          row_numbers: false,
          separators: true,
          titleize: true,
          layout: false, # Disable auto-layout to show full content
        }

        table_options = default_options.merge(options)
        TableTennis.new(array, table_options).to_s
      end

      # Format data as text
      #
      # @param data [Object] Data to format
      # @return [String] Formatted text
      def self.format_text(data)
        case data
        when Hash
          format_hash_table(data)
        when Array
          data.map(&:to_s).join("\n")
        else
          data.to_s
        end
      end

      # Format a tree structure with optional metadata
      #
      # @param node [Hash] Tree node with :name, :children, :classes_count,
      # :diagrams_count keys
      # @param prefix [String] Prefix for indentation
      # @param is_last [Boolean] Whether this is the last child
      # @param show_counts [Boolean] Whether to show class/diagram counts
      # @return [String] Formatted tree
      def self.format_tree(node, prefix: "", is_last: true, show_counts: true) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        return "" if node.nil?

        lines = []
        connector = is_last ? "└── " : "├── "

        # Build node display with optional counts
        node_text = node[:name]
        if show_counts
          metadata_parts = []
          if node[:classes_count]&.positive?
            metadata_parts << "#{node[:classes_count]} classes"
          end
          if node[:diagrams_count]&.positive?
            metadata_parts << "#{node[:diagrams_count]} diagrams"
          end

          unless metadata_parts.empty?
            node_text += " (#{metadata_parts.join(', ')})"
          end
        end

        lines << "#{prefix}#{connector}#{node_text}"

        children = node[:children] || []
        children.each_with_index do |child, index|
          child_is_last = (index == children.size - 1)
          extension = is_last ? "    " : "│   "
          lines << format_tree(child,
                               prefix: prefix + extension,
                               is_last: child_is_last,
                               show_counts: show_counts)
        end

        lines.join("\n")
      end

      # Format statistics output
      #
      # @param stats [Hash] Statistics hash
      # @param detailed [Boolean] Whether to show detailed stats
      # @return [String] Formatted statistics
      def self.format_stats(stats, detailed: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        return "No statistics available" unless stats

        lines = []

        lines << colorize("Repository Statistics", :cyan)
        lines << ("=" * 50)
        lines << ""

        # Basic counts
        lines << colorize("Basic Counts:", :yellow)
        lines << "  Total Packages:    #{stats[:total_packages] || 0}"
        lines << "  Total Classes:     #{stats[:total_classes] || 0}"
        lines << "  Total Data Types:  #{stats[:total_data_types] || 0}"
        lines << "  Total Enums:       #{stats[:total_enums] || 0}"
        lines << "  Total Diagrams:    #{stats[:total_diagrams] || 0}"
        lines << ""

        # Package statistics
        lines << colorize("Package Statistics:", :yellow)
        lines << "  Max Depth:         #{stats[:max_package_depth] || 0}"
        lines << "  Avg Depth:         " \
                 "#{'%.2f' % (stats[:avg_package_depth] || 0)}"

        if detailed && stats[:packages_by_depth]
          lines << "  Depth Distribution:"
          stats[:packages_by_depth].each do |depth, count|
            lines << "    Level #{depth}: #{count} package(s)"
          end
        end
        lines << ""

        # Class statistics
        lines << colorize("Class Statistics:", :yellow)
        lines << "  Total Attributes:   #{stats[:total_attributes] || 0}"
        lines << "  Total Associations: #{stats[:total_associations] || 0}"
        lines << "  Avg Complexity:     " \
                 "#{'%.2f' % (stats[:avg_class_complexity] || 0)}"

        if detailed && stats[:classes_by_stereotype] &&
            !stats[:classes_by_stereotype].empty?
          lines << "  By Stereotype:"
          stats[:classes_by_stereotype].each do |stereotype, count|
            lines << "    #{stereotype}: #{count}"
          end
        end
        lines << ""

        # Inheritance statistics
        if stats[:total_inheritance_relationships]
          lines << colorize("Inheritance:", :yellow)
          lines << "  Relationships:     " \
                   "#{stats[:total_inheritance_relationships]}"
          lines << "  Max Depth:         #{stats[:max_inheritance_depth]}"
          lines << ""
        end

        # Quality metrics
        if detailed
          lines << colorize("Quality Metrics:", :yellow)
          lines << "  Abstract Classes:  #{stats[:abstract_class_count] || 0}"
          lines << "  Undocumented:      " \
                   "#{stats[:classes_without_documentation] || 0}"
          lines << "  Without Attrs:     " \
                   "#{stats[:classes_without_attributes] || 0}"
          lines << ""
        end

        # Most complex classes
        if detailed && stats[:most_complex_classes] &&
            !stats[:most_complex_classes].empty?
          lines << colorize("Most Complex Classes:", :yellow)
          stats[:most_complex_classes].first(5).each do |item|
            klass = item[:class]
            complexity = item[:complexity]
            class_name = klass.respond_to?(:name) ? klass.name : klass.to_s

            lines << "  #{class_name} (complexity: #{complexity})"
          end
        end

        lines.join("\n")
      end

      # Colorize text for terminal output
      #
      # @param text [String] Text to colorize
      # @param color [Symbol] Color name
      # @return [String] Colorized text
      def self.colorize(text, color)
        return text unless $stdout.tty?

        "#{COLORS[color]}#{text}#{COLORS[:reset]}"
      end

      # Format success message
      #
      # @param message [String] Message to format
      # @return [String] Formatted message
      def self.success(message)
        colorize("✓ #{message}", :green)
      end

      # Format error message
      #
      # @param message [String] Message to format
      # @return [String] Formatted message
      def self.error(message)
        colorize("✗ #{message}", :red)
      end

      # Format warning message
      #
      # @param message [String] Message to format
      # @return [String] Formatted message
      def self.warning(message)
        colorize("⚠ #{message}", :yellow)
      end

      # Format info message
      #
      # @param message [String] Message to format
      # @return [String] Formatted message
      def self.info(message)
        colorize("ℹ #{message}", :blue)
      end

      # Show progress indicator
      #
      # @param message [String] Progress message
      # @return [void]
      def self.progress(message)
        print colorize("⋯ #{message}...", :cyan)
        $stdout.flush
      end

      # Complete progress indicator
      #
      # @param success [Boolean] Whether operation succeeded
      # @return [void]
      def self.progress_done(success: true)
        if success
          puts " #{colorize('✓', :green)}"
        else
          puts " #{colorize('✗', :red)}"
        end
      end
    end
  end
end
