# frozen_string_literal: true

require "io/console"
require "table_tennis"
require_relative "output_formatter"

module Lutaml
  module Cli
    # EnhancedFormatter provides advanced formatting capabilities
    # with icons, pagination, and interactive features
    #
    # Features:
    # - Tree views with Unicode icons
    # - Paginated tables for large datasets
    # - Enhanced class details with visual formatting
    # - Interactive navigation for paginated content
    class EnhancedFormatter < OutputFormatter
      # Unicode icons for different element types
      ICONS = {
        package: "📦",
        class: "📋",
        enum: "🔢",
        datatype: "📊",
        diagram: "🖼️",
        favorite: "⭐",
        complex: "🔥",
        attribute: "🔹",
        operation: "⚙️",
        association: "🔗",
        inheritance: "⬆️",
        folder: "📁",
        file: "📄",
      }.freeze

      # Tree drawing characters
      TREE_CHARS = {
        vertical: "│",
        horizontal: "─",
        branch: "├",
        corner: "└",
        tee: "┬",
      }.freeze

      # Format a tree structure with icons and metadata
      #
      # @param node [Hash] Tree node with :name, :type, :metadata, :children
      # @param config [Hash] Configuration options
      # @option config [Boolean] :show_icons Display icons
      # @option config [Boolean] :show_counts Display counts in metadata
      # @option config [Boolean] :show_complexity Highlight complex nodes
      # @param prefix [String] Current indentation prefix
      # @param is_last [Boolean] Whether this is the last sibling
      # @return [String] Formatted tree with icons
      def self.format_tree_with_icons(node, config = {}, prefix: "",
is_last: true)
        return "" if node.nil?

        config = {
          show_icons: true,
          show_counts: true,
          show_complexity: false,
        }.merge(config)

        lines = []
        connector = is_last ? "#{TREE_CHARS[:corner]}#{TREE_CHARS[:horizontal]}#{TREE_CHARS[:horizontal]} " : "#{TREE_CHARS[:branch]}#{TREE_CHARS[:horizontal]}#{TREE_CHARS[:horizontal]} "

        # Build node display
        icon = config[:show_icons] ? get_icon(node) : ""
        name = node[:name] || "unknown"
        metadata = build_metadata_string(node, config)

        node_text = "#{icon}#{name}#{metadata}"
        lines << "#{prefix}#{connector}#{node_text}"

        # Process children
        children = node[:children] || []
        children.each_with_index do |child, index|
          child_is_last = (index == children.size - 1)
          extension = is_last ? "    " : "#{TREE_CHARS[:vertical]}   "
          lines << format_tree_with_icons(
            child,
            config,
            prefix: prefix + extension,
            is_last: child_is_last,
          )
        end

        lines.join("\n")
      end

      # Format a table with pagination support
      #
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] Data rows
      # @param options [Hash] Pagination options
      # @option options [Integer] :page_size Number of rows per page (default: 50)
      # @option options [Boolean] :interactive Enable interactive navigation
      # @option options [Integer] :current_page Starting page (default: 1)
      # @return [String] Formatted and optionally paginated table
      def self.format_table_with_pagination(headers, rows, options = {})
        page_size = options[:page_size] || 50
        interactive = options[:interactive] != false
        current_page = options[:current_page] || 1

        return format_simple_table(headers, rows) if rows.size <= page_size

        if interactive && $stdout.tty?
          interactive_paginated_table(headers, rows, page_size, current_page)
        else
          non_interactive_paginated_table(headers, rows, page_size,
                                          current_page)
        end
      end

      # Format class details with enhanced visual formatting
      #
      # @param klass [Object] Class object to display
      # @param path_formatter [Proc] Formatter for package paths
      # @return [String] Enhanced class details
      def self.format_class_details_enhanced(klass, path_formatter = nil)
        lines = []

        # Header box
        lines << "╔#{'═' * 78}╗"
        class_name = "#{ICONS[:class]} #{klass.name}"
        lines << "║ #{class_name.ljust(76)} ║"
        lines << "╚#{'═' * 78}╝"
        lines << ""

        # Basic information
        lines << colorize("Basic Information:", :cyan)
        if klass.respond_to?(:xmi_id)
          lines << "  XMI ID:      #{klass.xmi_id}"
        end
        if klass.respond_to?(:stereotype) && klass.stereotype
          lines << "  Stereotype:  #{klass.stereotype}"
        end
        if klass.respond_to?(:is_abstract)
          lines << "  Abstract:    #{klass.is_abstract ? 'Yes' : 'No'}"
        end
        if path_formatter && klass.respond_to?(:package)
          package_path = path_formatter.call(klass.package)
          lines << "  Package:     #{ICONS[:package]} #{package_path}"
        end
        lines << ""

        # Attributes
        if klass.respond_to?(:attributes) && klass.attributes && !klass.attributes.empty?
          lines << colorize(
            "#{ICONS[:attribute]} Attributes (#{klass.attributes.size}):", :yellow
          )
          attr_data = klass.attributes.map do |attr|
            {
              name: attr.name,
              type: attr.type || "Unknown",
              cardinality: format_cardinality(attr),
            }
          end
          lines << indent_text(format_array_table(attr_data), 2)
          lines << ""
        end

        # Operations
        if klass.respond_to?(:operations) && klass.operations && !klass.operations.empty?
          lines << colorize(
            "#{ICONS[:operation]} Operations (#{klass.operations.size}):", :yellow
          )
          klass.operations.each do |op|
            params = if op.respond_to?(:parameters) && op.parameters
                       op.parameters.map do |p|
                         "#{p.name}: #{p.type}"
                       end.join(", ")
                     else
                       ""
                     end
            return_type = if op.respond_to?(:return_type) && op.return_type
                            " : #{op.return_type}"
                          else
                            ""
                          end
            lines << "  #{ICONS[:operation]} #{op.name}(#{params})#{return_type}"
          end
          lines << ""
        end

        lines.join("\n")
      end

      # Format a box around text
      #
      # @param text [String] Text to box
      # @param width [Integer] Box width
      # @return [String] Boxed text
      def self.format_box(text, width: 80)
        lines = []
        lines << "┌#{'─' * (width - 2)}┐"
        text.split("\n").each do |line|
          padded = line.ljust(width - 4)
          lines << "│ #{padded} │"
        end
        lines << "└#{'─' * (width - 2)}┘"
        lines.join("\n")
      end

      # Format statistics with visual enhancements
      #
      # @param stats [Hash] Statistics data
      # @param options [Hash] Display options
      # @return [String] Formatted statistics
      def self.format_stats_enhanced(stats, options = {})
        lines = []

        # Header
        lines << colorize("╔#{'═' * 78}╗", :cyan)
        header = "Repository Statistics"
        padding = (78 - header.length) / 2
        lines << colorize(
          "║#{' ' * padding}#{header}#{' ' * (78 - padding - header.length)}║", :cyan
        )
        lines << colorize("╚#{'═' * 78}╝", :cyan)
        lines << ""

        # Package stats
        lines << colorize("#{ICONS[:package]} Packages", :yellow)
        lines << "  Total:        #{stats[:total_packages]}"
        lines << "  Max Depth:    #{stats[:max_package_depth]}"
        lines << "  Avg Depth:    #{'%.2f' % stats[:avg_package_depth]}"
        lines << ""

        # Class stats
        lines << colorize("#{ICONS[:class]} Classes", :yellow)
        lines << "  Total:        #{stats[:total_classes]}"
        lines << "  Data Types:   #{stats[:total_data_types]}"
        lines << "  Enumerations: #{stats[:total_enums]}"
        lines << "  Attributes:   #{stats[:total_attributes]}"
        lines << "  Operations:   #{stats[:total_operations] || 0}"
        lines << ""

        # Relationships
        lines << colorize("#{ICONS[:association]} Relationships", :yellow)
        lines << "  Associations: #{stats[:total_associations]}"
        if stats[:total_inheritance_relationships]
          lines << "  Inheritance:  #{stats[:total_inheritance_relationships]}"
          lines << "  Max Depth:    #{stats[:max_inheritance_depth]}"
        end
        lines << ""

        # Diagrams
        if stats[:total_diagrams]&.positive?
          lines << colorize("#{ICONS[:diagram]} Diagrams", :yellow)
          lines << "  Total:        #{stats[:total_diagrams]}"
          lines << ""
        end

        # Complexity indicators
        if options[:show_complexity] && stats[:avg_class_complexity]
          lines << colorize("#{ICONS[:complex]} Complexity Metrics", :yellow)
          lines << "  Avg Complexity: #{'%.2f' % stats[:avg_class_complexity]}"
          if stats[:most_complex_classes] && !stats[:most_complex_classes].empty?
            lines << "  Most Complex:"
            stats[:most_complex_classes].first(3).each do |cls|
              complexity_icon = cls[:total_complexity] > 10 ? ICONS[:complex] : ICONS[:class]
              lines << "    #{complexity_icon} #{cls[:name]} (#{cls[:total_complexity]})"
            end
          end
        end

        lines.join("\n")
      end

      # Get appropriate icon for a node
      #
      # @param node [Hash] Node with :type key
      # @return [String] Icon with trailing space
      def self.get_icon(node)
        icon_key = node[:type]&.to_sym || :package
        icon = ICONS[icon_key] || ICONS[:package]
        "#{icon} "
      end

      # Build metadata string for tree node
      #
      # @param node [Hash] Node with metadata
      # @param config [Hash] Display configuration
      # @return [String] Formatted metadata
      def self.build_metadata_string(node, config)
        parts = []

        if config[:show_counts] && node[:count]
          parts << " (#{node[:count]} classes)"
        end

        if config[:show_complexity] && node[:complexity] && (node[:complexity] > 10)
          parts << " #{ICONS[:complex]}"
        end

        if node[:favorite]
          parts << " #{ICONS[:favorite]}"
        end

        parts.join
      end

      # Format a simple table without pagination using TableTennis
      #
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] Data rows
      # @param options [Hash] TableTennis options
      # @return [String] Formatted table
      def self.format_simple_table(headers, rows, options: {})
        return "" if rows.empty?

        # Convert to array of hashes for TableTennis
        data = rows.map do |row|
          headers.each_with_index.to_h { |h, i| [h.to_sym, row[i]] }
        end

        # Default options with zebra and separators
        default_options = {
          zebra: true,
          separators: true,
          titleize: false,
        }

        table_options = default_options.merge(options)
        TableTennis.new(data, table_options).to_s
      end

      # Interactive paginated table navigation
      #
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] All data rows
      # @param page_size [Integer] Rows per page
      # @param current_page [Integer] Starting page
      # @return [String] Final page output
      def self.interactive_paginated_table(headers, rows, page_size,
current_page)
        total_pages = (rows.size.to_f / page_size).ceil
        page = current_page

        loop do
          clear_screen
          page_rows = rows[(page - 1) * page_size, page_size]
          col_widths = calculate_column_widths(headers, page_rows)

          puts format_table_content(headers, page_rows, col_widths)
          puts ""
          puts colorize(
            "Page #{page}/#{total_pages} (#{rows.size} total rows)", :cyan
          )
          puts ""
          puts "Navigation: [N]ext, [P]revious, [J]ump, [Q]uit"
          print "> "

          input = $stdin.gets&.chomp&.downcase
          case input
          when "n", ""
            page = [page + 1, total_pages].min
          when "p"
            page = [page - 1, 1].max
          when "j"
            print "Jump to page (1-#{total_pages}): "
            jump_page = $stdin.gets&.chomp&.to_i
            page = [[jump_page, 1].max, total_pages].min
          when "q"
            break
          end
        end

        # Return final page content
        page_rows = rows[(page - 1) * page_size, page_size]
        col_widths = calculate_column_widths(headers, page_rows)
        format_table_content(headers, page_rows, col_widths)
      end

      # Non-interactive paginated table
      #
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] All data rows
      # @param page_size [Integer] Rows per page
      # @param current_page [Integer] Page to display
      # @return [String] Formatted page
      def self.non_interactive_paginated_table(headers, rows, page_size,
current_page)
        total_pages = (rows.size.to_f / page_size).ceil
        page = [[current_page, 1].max, total_pages].min

        page_rows = rows[(page - 1) * page_size, page_size]
        col_widths = calculate_column_widths(headers, page_rows)

        output = []
        output << format_table_content(headers, page_rows, col_widths)
        output << ""
        output << colorize(
          "Page #{page}/#{total_pages} (#{rows.size} total rows)", :cyan
        )
        output.join("\n")
      end

      # Calculate column widths for table
      #
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] Data rows
      # @return [Array<Integer>] Column widths
      def self.calculate_column_widths(headers, rows)
        headers.each_with_index.map do |header, i|
          max_content = rows.map { |row| row[i].to_s.length }.max || 0
          [header.to_s.length, max_content].max
        end
      end

      # Format table content with headers and rows
      #
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] Data rows
      # @param col_widths [Array<Integer>] Column widths
      # @return [String] Formatted table
      def self.format_table_content(headers, rows, col_widths)
        lines = []

        # Header row
        header_line = headers.each_with_index.map do |header, i|
          header.to_s.ljust(col_widths[i])
        end.join(" │ ")
        lines << header_line

        # Separator
        separator = col_widths.map { |w| "─" * w }.join("─┼─")
        lines << separator

        # Data rows
        rows.each do |row|
          data_line = headers.each_with_index.map do |_, i|
            row[i].to_s.ljust(col_widths[i])
          end.join(" │ ")
          lines << data_line
        end

        lines.join("\n")
      end

      # Clear the terminal screen
      #
      # @return [void]
      def self.clear_screen
        print "\e[2J\e[H"
      end

      # Indent text by a number of spaces
      #
      # @param text [String] Text to indent
      # @param spaces [Integer] Number of spaces
      # @return [String] Indented text
      def self.indent_text(text, spaces)
        indent = " " * spaces
        text.split("\n").map { |line| "#{indent}#{line}" }.join("\n")
      end

      # Format cardinality for display
      #
      # @param attr [Object] Attribute with cardinality
      # @return [String] Formatted cardinality
      def self.format_cardinality(attr)
        return "" unless attr.respond_to?(:cardinality)
        return "" unless attr.cardinality

        card = attr.cardinality
        if card.respond_to?(:min) && card.respond_to?(:max)
          min = card.min || "0"
          max = card.max || "*"
          "[#{min}..#{max}]"
        else
          ""
        end
      end
    end
  end
end
