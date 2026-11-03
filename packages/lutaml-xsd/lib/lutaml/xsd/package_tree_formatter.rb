# frozen_string_literal: true

require "paint"

module Lutaml
  module Xsd
    # Formats LXR package contents as a colorized tree structure
    #
    # Responsibilities:
    # - Extract and organize package file listing
    # - Generate colorized tree output with appropriate icons
    # - Handle different output formats (tree, flat)
    # - Calculate and display file sizes
    #
    # @example Basic usage
    #   formatter = PackageTreeFormatter.new(package_path)
    #   puts formatter.format
    #
    # @example With options
    #   formatter = PackageTreeFormatter.new(
    #     package_path,
    #     show_sizes: true,
    #     no_color: false,
    #     format: :tree
    #   )
    #   puts formatter.format
    class PackageTreeFormatter
      # Color scheme for different file types
      COLORS = {
        directory: %i[cyan bold],
        xsd_file: :green,
        metadata_file: :yellow,
        serialized_file: :blue,
        index_file: :magenta,
        file_size: :black,
        summary_label: [:bold],
        summary_value: %i[cyan bold],
      }.freeze

      # Icons for different file types
      ICONS = {
        directory: "📁",
        metadata: "📋",
        xsd: "📄",
        index: "🔍",
        mapping: "🔖",
        relation: "🔗",
      }.freeze

      attr_reader :package_path, :options

      # Initialize formatter
      #
      # @param package_path [String] Path to .lxr package file
      # @param options [Hash] Formatting options
      # @option options [Boolean] :show_sizes Show file sizes (default: false)
      # @option options [Boolean] :no_color Disable colored output (default: false)
      # @option options [Symbol] :format Output format :tree or :flat (default: :tree)
      def initialize(package_path, options = {})
        @package_path = package_path
        @options = {
          show_sizes: false,
          no_color: false,
          format: :tree,
        }.merge(options)
      end

      # Format package contents as tree
      #
      # @return [String] Formatted tree output
      def format
        entries = extract_entries
        stats = calculate_statistics(entries)

        output = []
        output << format_header(stats[:total_size])
        output << format_entries(entries) if options[:format] == :tree
        output << format_flat_list(entries) if options[:format] == :flat
        output << ""
        output << format_summary(stats)

        output.join("\n")
      end

      private

      # Extract all entries from package
      #
      # @return [Hash] Organized entries by category
      def extract_entries
        require "zip"

        entries = {
          metadata: [],
          xsd_files: [],
          schemas_data: [],
          indexes: [],
          mappings: [],
        }

        Zip::File.open(package_path) do |zipfile|
          zipfile.each do |entry|
            next if entry.directory?

            categorize_entry(entry, entries)
          end
        end

        entries
      rescue Zip::Error => e
        raise Error, "Failed to read package: #{e.message}"
      end

      # Categorize a ZIP entry
      #
      # @param entry [Zip::Entry] ZIP file entry
      # @param entries [Hash] Entries hash to update
      def categorize_entry(entry, entries)
        case entry.name
        when "metadata.yaml"
          entries[:metadata] << create_entry_info(entry)
        when %r{^schemas/.+\.xsd$}
          entries[:xsd_files] << create_entry_info(entry)
        when %r{^schemas_data/}
          entries[:schemas_data] << create_entry_info(entry)
        when /type_index\.(marshal|json|yaml)$/
          entries[:indexes] << create_entry_info(entry)
        when /namespace_mappings\.yaml$/
          entries[:mappings] << create_entry_info(entry)
        when /schema_location_mappings\.yaml$/
          entries[:mappings] << create_entry_info(entry)
        end
      end

      # Create entry information hash
      #
      # @param entry [Zip::Entry] ZIP file entry
      # @return [Hash] Entry information
      def create_entry_info(entry)
        {
          name: File.basename(entry.name),
          path: entry.name,
          size: entry.size,
          directory: entry.name.include?("/") ? File.dirname(entry.name).split("/").last : nil,
        }
      end

      # Calculate statistics
      #
      # @param entries [Hash] Organized entries
      # @return [Hash] Statistics
      def calculate_statistics(entries)
        xsd_count = entries[:xsd_files].size
        serialized_count = entries[:schemas_data].size
        config_count = entries[:metadata].size + entries[:mappings].size
        index_count = entries[:indexes].size
        total_files = xsd_count + serialized_count + config_count + index_count

        total_size = File.size(package_path)

        {
          total_files: total_files,
          xsd_files: xsd_count,
          serialized_schemas: serialized_count,
          configuration_files: config_count,
          indexes: index_count,
          total_size: total_size,
        }
      end

      # Format package header
      #
      # @param total_size [Integer] Total package size in bytes
      # @return [String] Formatted header
      def format_header(total_size)
        package_name = File.basename(package_path)
        size_str = format_size(total_size)
        colorize("#{package_name} (#{size_str})", :summary_label)
      end

      # Format entries as tree structure
      #
      # @param entries [Hash] Organized entries
      # @return [String] Tree structure
      def format_entries(entries)
        lines = []

        # Metadata
        if entries[:metadata].any?
          entries[:metadata].each do |entry|
            lines << format_tree_line(entry, ICONS[:metadata], :metadata_file,
                                      0)
          end
        end

        # XSD files (grouped) - show ALL files, no truncation
        if entries[:xsd_files].any?
          lines << format_directory_line("xsd_files", entries[:xsd_files].sum { |e|
            e[:size]
          }, 0)
          entries[:xsd_files].each do |entry|
            lines << format_tree_line(entry, ICONS[:xsd], :xsd_file, 1)
          end
        end

        # Serialized schemas - show ALL files, no truncation
        if entries[:schemas_data].any?
          lines << format_directory_line("schemas_data", entries[:schemas_data].sum { |e|
            e[:size]
          }, 0)
          entries[:schemas_data].each do |entry|
            lines << format_tree_line(entry, "📦", :serialized_file, 1)
          end
        end

        # Indexes
        entries[:indexes].each do |entry|
          lines << format_tree_line(entry, ICONS[:index], :index_file, 0)
        end

        # Mappings
        entries[:mappings].each do |entry|
          icon = entry[:name].include?("namespace") ? ICONS[:mapping] : ICONS[:relation]
          lines << format_tree_line(entry, icon, :metadata_file, 0)
        end

        lines.join("\n")
      end

      # Format directory line
      #
      # @param name [String] Directory name
      # @param total_size [Integer] Total size of contents
      # @param level [Integer] Indentation level
      # @return [String] Formatted line
      def format_directory_line(name, total_size, level)
        prefix = indent_prefix(level, false)
        size_str = options[:show_sizes] ? " (#{format_size(total_size)})" : ""
        line = "#{prefix}#{ICONS[:directory]} #{name}/#{size_str}"
        colorize(line, :directory)
      end

      # Format tree line for a file
      #
      # @param entry [Hash] Entry information
      # @param icon [String] Icon to display
      # @param color_key [Symbol] Color scheme key
      # @param level [Integer] Indentation level
      # @return [String] Formatted line
      def format_tree_line(entry, icon, color_key, level)
        prefix = indent_prefix(level, true)
        size_str = if options[:show_sizes]
                     " #{colorize(
                       format_size(entry[:size]), :file_size
                     )}"
                   else
                     ""
                   end
        line = "#{prefix}#{icon} #{entry[:name]}#{size_str}"
        colorize(line, color_key)
      end

      # Create indentation prefix
      #
      # @param level [Integer] Indentation level
      # @param is_item [Boolean] Whether this is an item (vs directory)
      # @return [String] Indentation prefix
      def indent_prefix(level, is_item)
        return "├── " if level.zero? && is_item
        return "" if level.zero?

        base = "│   " * (level - 1)
        connector = is_item ? "├── " : "├── "
        "│   #{base}#{connector}"
      end

      # Format indented line
      #
      # @param text [String] Text to indent
      # @param level [Integer] Indentation level
      # @return [String] Indented line
      def indent_line(text, level)
        prefix = "│   " * level
        "#{prefix}#{text}"
      end

      # Format flat list
      #
      # @param entries [Hash] Organized entries
      # @return [String] Flat list
      def format_flat_list(entries)
        lines = []

        all_files = []
        all_files.concat(entries[:metadata].map { |e| [e, :metadata_file] })
        all_files.concat(entries[:xsd_files].map { |e| [e, :xsd_file] })
        all_files.concat(entries[:schemas_data].map do |e|
          [e, :serialized_file]
        end)
        all_files.concat(entries[:indexes].map { |e| [e, :index_file] })
        all_files.concat(entries[:mappings].map { |e| [e, :metadata_file] })

        all_files.each do |entry, color_key|
          size_str = if options[:show_sizes]
                       " #{colorize(
                         format_size(entry[:size]), :file_size
                       )}"
                     else
                       ""
                     end
          lines << colorize("#{entry[:path]}#{size_str}", color_key)
        end

        lines.join("\n")
      end

      # Format summary section
      #
      # @param stats [Hash] Statistics
      # @return [String] Formatted summary
      def format_summary(stats)
        lines = []
        lines << colorize("Summary:", :summary_label)
        lines << "  #{colorize('Total files:',
                               :summary_label)} #{colorize(
                                 stats[:total_files].to_s, :summary_value
                               )}"
        lines << "  #{colorize('XSD files:',
                               :summary_label)} #{colorize(
                                 stats[:xsd_files].to_s, :summary_value
                               )}"
        lines << "  #{colorize('Serialized schemas:',
                               :summary_label)} #{colorize(
                                 stats[:serialized_schemas].to_s, :summary_value
                               )}"
        lines << "  #{colorize('Configuration files:',
                               :summary_label)} #{colorize(
                                 stats[:configuration_files].to_s, :summary_value
                               )}"
        lines << "  #{colorize('Indexes:',
                               :summary_label)} #{colorize(
                                 stats[:indexes].to_s, :summary_value
                               )}"
        lines.join("\n")
      end

      # Format file size
      #
      # @param bytes [Integer] Size in bytes
      # @return [String] Formatted size
      def format_size(bytes)
        return "0 B" if bytes.zero?

        units = %w[B KB MB GB TB]
        exp = (Math.log(bytes) / Math.log(1024)).to_i
        exp = [exp, units.length - 1].min

        Kernel.format("%.1f %s", bytes.to_f / (1024**exp), units[exp])
      end

      # Colorize text if colors enabled
      #
      # @param text [String] Text to colorize
      # @param color_key [Symbol] Color scheme key
      # @return [String] Colorized or plain text
      def colorize(text, color_key)
        return text if options[:no_color]

        color = COLORS[color_key]
        return text unless color

        if color.is_a?(Array)
          Paint[text, *color]
        else
          Paint[text, color]
        end
      end
    end
  end
end
