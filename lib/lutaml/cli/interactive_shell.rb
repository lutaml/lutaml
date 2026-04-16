# frozen_string_literal: true

require "readline"
require "pathname"
require_relative "enhanced_formatter"
require_relative "../uml_repository/repository"

module Lutaml
  module Cli
    # InteractiveShell provides a full-featured REPL for
    # exploring UML repositories
    #
    # Features:
    # - Readline integration with history
    # - Tab completion for commands and paths
    # - Colorized prompts and output
    # - Navigation commands (cd, pwd, ls, tree, up, root, back)
    # - Query commands (find, show, search)
    # - Bookmark management
    # - Results management
    # - Command history persistence
    class InteractiveShell
      HISTORY_FILE = File.expand_path("~/.lutaml-xmi-history")
      MAX_HISTORY = 1000

      attr_reader :repository, :current_path, :config, :bookmarks,
                  :last_results, :path_history

      # Initialize the interactive shell
      #
      # @param lur_path_or_repo [String, UmlRepository] Path to LUR file or
      # repository
      # @param config [Hash] Configuration options
      # @option config [Boolean] :color Enable colored output
      # @option config [Boolean] :icons Enable icons in output
      def initialize(lur_path_or_repo, config: nil) # rubocop:disable Metrics/MethodLength
        @config = {
          color: true,
          icons: true,
          show_counts: true,
          page_size: 50,
        }.merge(config || {})

        # Load repository
        if lur_path_or_repo.is_a?(String)
          OutputFormatter.progress("Loading repository")
          @repository = Lutaml::UmlRepository::Repository.from_package(lur_path_or_repo)
          OutputFormatter.progress_done
        else
          @repository = lur_path_or_repo
        end

        # Initialize state
        @current_path = "ModelRoot"
        @bookmarks = {}
        @last_results = nil
        @path_history = ["ModelRoot"]
        @running = false

        setup_readline
        load_history
      end

      # Start the REPL loop
      #
      # @return [void]
      def start # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        @running = true
        display_welcome

        while @running
          begin
            input = Readline.readline(prompt, true)

            # Exit on Ctrl+D or nil input
            break if input.nil?

            # Skip empty lines
            next if input.strip.empty?

            # Don't save duplicates in history
            if Readline::HISTORY.length > 1 &&
                Readline::HISTORY[-2] == input
              Readline::HISTORY.pop
            end

            execute_command(input.strip)
          rescue Interrupt
            puts "\nUse 'exit' or 'quit' to exit the shell"
          rescue StandardError => e
            puts OutputFormatter.error("Error: #{e.message}")
            puts e.backtrace.first(3).join("\n") if ENV["DEBUG"]
          end
        end

        save_history
        puts "\nGoodbye!"
      end

      private

      # Generate contextual prompt
      #
      # @return [String] Formatted prompt
      def prompt
        path_display = @current_path == "ModelRoot" ? "/" : "/#{@current_path}"
        prompt_text = "lutaml[#{path_display}]> "

        if @config[:color] && $stdout.tty?
          OutputFormatter.colorize(prompt_text, :green)
        else
          prompt_text
        end
      end

      # Setup readline with tab completion and history
      #
      # @return [void]
      def setup_readline
        # Tab completion
        Readline.completion_proc = proc do |word|
          complete_command(word)
        end

        Readline.completion_append_character = " "
      end

      # Load command history from file
      #
      # @return [void]
      def load_history
        return unless File.exist?(HISTORY_FILE)

        File.readlines(HISTORY_FILE).each do |line|
          Readline::HISTORY.push(line.chomp)
        end
      rescue StandardError => e
        # Silently ignore history load errors
        warn "Warning: Could not load history: #{e.message}" if ENV["DEBUG"]
      end

      # Save command history to file
      #
      # @return [void]
      def save_history
        history_lines = Readline::HISTORY.to_a.last(MAX_HISTORY)
        File.write(HISTORY_FILE, history_lines.join("\n"))
      rescue StandardError => e
        warn "Warning: Could not save history: #{e.message}"
      end

      # Display welcome message
      #
      # @return [void]
      def display_welcome # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        puts OutputFormatter.colorize(
          "╔═══════════════════════════════════════╗", :cyan
        )
        puts OutputFormatter.colorize(
          "║  LutaML Interactive Shell (REPL)     ║", :cyan
        )
        puts OutputFormatter.colorize(
          "╚═══════════════════════════════════════╝", :cyan
        )
        puts ""
        puts "Type 'help' for available commands, 'exit' to quit"
        puts ""

        # Show quick stats
        stats = @repository.statistics
        puts "Repository loaded:"
        puts "  #{stats[:total_packages]} packages, " \
             "#{stats[:total_classes]} classes"
        puts ""
      end

      # Execute a command
      #
      # @param input [String] User input
      # @return [void]
      def execute_command(input) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        parts = input.split(/\s+/)
        command = parts[0].downcase
        args = parts[1..]

        case command
        # Navigation
        when "cd"
          cmd_cd(args)
        when "pwd"
          cmd_pwd(args)
        when "ls", "list"
          cmd_ls(args)
        when "tree"
          cmd_tree(args)
        when "up"
          cmd_up(args)
        when "root"
          cmd_root(args)
        when "back"
          cmd_back(args)

        # Query
        when "find", "f"
          cmd_find(args)
        when "show", "s"
          cmd_show(args)
        when "search", "?"
          cmd_search(args)

        # Bookmarks
        when "bookmark", "bm"
          cmd_bookmark(args)

        # Results
        when "results"
          cmd_results(args)
        when "export"
          cmd_export(args)

        # Utilities
        when "help", "h"
          cmd_help(args)
        when "history"
          cmd_history(args)
        when "clear", "cls"
          cmd_clear(args)
        when "config"
          cmd_config(args)
        when "stats"
          cmd_stats(args)
        when "exit", "quit", "q"
          @running = false

        else
          puts OutputFormatter.warning("Unknown command: #{command}")
          puts "Type 'help' for available commands"
        end
      end

      # Tab completion for commands
      #
      # @param word [String] Word to complete
      # @return [Array<String>] Completion options
      def complete_command(word)
        commands = %w[
          cd pwd ls list tree up root back
          find show search
          bookmark bm
          results export
          help history clear config stats exit quit
        ]

        commands.grep(/^#{Regexp.escape(word)}/)
      end

      # Navigation: Change directory
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_cd(args) # rubocop:disable Metrics/MethodLength
        if args.empty?
          puts OutputFormatter.warning("Usage: cd PATH")
          return
        end

        path = resolve_path(args[0])
        pkg = @repository.find_package(path)

        if pkg
          unless @path_history.last == @current_path
            @path_history << @current_path
          end
          @current_path = path
          puts "Changed to: #{path}"
        else
          puts OutputFormatter.error("Package not found: #{path}")
        end
      end

      # Navigation: Print working directory
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_pwd(_args)
        puts @current_path
      end

      # Navigation: List packages
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_ls(args) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/PerceivedComplexity
        path = args.empty? ? @current_path : resolve_path(args[0])
        recursive = args.include?("-r") || args.include?("--recursive")

        packages = @repository.list_packages(path, recursive: recursive)

        if packages.empty?
          puts OutputFormatter.warning("No packages found at #{path}")
        else
          packages.each do |pkg|
            icon = if @config[:icons]
                     "#{EnhancedFormatter::ICONS[:package]} "
                   else
                     ""
                   end
            puts "#{icon}#{pkg.name}"
          end
          puts ""
          puts "Total: #{packages.size} package(s)"
        end
      end

      # Navigation: Show tree
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_tree(args) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        path = args.empty? ? @current_path : resolve_path(args[0])

        # Parse depth option
        max_depth = nil
        args.each_with_index do |arg, i|
          if arg == "-d" && args[i + 1]
            max_depth = args[i + 1].to_i
          end
        end

        tree_data = @repository.package_tree(path, max_depth: max_depth)

        unless tree_data
          puts OutputFormatter.error("Package not found: #{path}")
          return
        end

        if @config[:icons]
          puts EnhancedFormatter.format_tree_with_icons(tree_data, @config)
        else
          puts OutputFormatter.format_tree(tree_data)
        end
      end

      # Navigation: Go up one level
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_up(_args) # rubocop:disable Metrics/MethodLength
        if @current_path == "ModelRoot"
          puts OutputFormatter.warning("Already at root")
          return
        end

        parts = @current_path.split("::")
        parts.pop
        new_path = parts.empty? ? "ModelRoot" : parts.join("::")

        unless @path_history.last == @current_path
          @path_history << @current_path
        end
        @current_path = new_path
        puts "Changed to: #{@current_path}"
      end

      # Navigation: Go to root
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_root(_args)
        if @current_path == "ModelRoot"
          puts "Already at root"
        else
          unless @path_history.last == @current_path
            @path_history << @current_path
          end
          @current_path = "ModelRoot"
          puts "Changed to: ModelRoot"
        end
      end

      # Navigation: Go back to previous location
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_back(_args)
        if @path_history.size > 1
          @path_history.pop
          @current_path = @path_history.last
          puts "Changed to: #{@current_path}"
        else
          puts OutputFormatter.warning("No previous location")
        end
      end

      # Query: Find class by name
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_find(args) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if args.empty?
          puts OutputFormatter.warning("Usage: find CLASS_NAME")
          return
        end

        query = args.join(" ")
        results = @repository.search(query, types: [:class])

        if results[:class].empty?
          puts OutputFormatter.warning("No classes found matching '#{query}'")
        else
          @last_results = results[:class]

          puts OutputFormatter.colorize(
            "Found #{@last_results.size} class(es):", :cyan
          )
          @last_results.each_with_index do |qname, i|
            puts "  #{i + 1}. #{qname}"
          end
          puts ""
          puts "Use 'show NUMBER' to view details"
        end
      end

      # Query: Show details
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_show(args) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if args.empty?
          puts OutputFormatter.warning(
            "Usage: show class QNAME | show package PATH | show NUMBER",
          )
          return
        end

        subcommand = args[0].downcase

        case subcommand
        when "class"
          show_class(args[1..].join(" "))
        when "package"
          show_package(args[1..].join(" "))
        when /^\d+$/
          show_numbered_result(subcommand.to_i)
        else
          # Try as class name
          show_class(args.join(" "))
        end
      end

      # Query: Full-text search
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_search(args) # rubocop:disable Metrics/MethodLength
        if args.empty?
          puts OutputFormatter.warning("Usage: search QUERY")
          return
        end

        query = args.join(" ")
        results = @repository.search(query)

        if results.values.all?(&:empty?)
          puts OutputFormatter.warning("No results found for '#{query}'")
        else
          display_search_results(results)
        end
      end

      # Bookmarks: Manage bookmarks
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_bookmark(args) # rubocop:disable Metrics/MethodLength
        return bookmark_list if args.empty?

        subcommand = args[0].downcase

        case subcommand
        when "add"
          bookmark_add(args[1])
        when "list"
          bookmark_list
        when "go"
          bookmark_go(args[1])
        when "rm", "remove"
          bookmark_remove(args[1])
        else
          # Quick jump
          bookmark_go(subcommand)
        end
      end

      # Results: Show last search results
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_results(_args)
        if @last_results.nil? || @last_results.empty?
          puts OutputFormatter.warning("No previous results")
        else
          puts OutputFormatter.colorize(
            "Last results (#{@last_results.size}):", :cyan
          )
          @last_results.each_with_index do |item, i|
            puts "  #{i + 1}. #{item}"
          end
        end
      end

      # Export: Export results
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_export(args) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        if @last_results.nil? || @last_results.empty?
          puts OutputFormatter.warning("No results to export")
          return
        end

        if args.size < 3 || args[0] != "last"
          puts OutputFormatter.warning("Usage: export last FORMAT FILE")
          return
        end

        format = args[1].downcase
        file_path = args[2]

        case format
        when "csv"
          export_csv(file_path)
        when "json"
          export_json(file_path)
        when "yaml"
          export_yaml(file_path)
        else
          puts OutputFormatter.error("Unsupported format: #{format}")
        end
      end

      # Utilities: Show help
      #
      # @param args [Array<String>] Command arguments
      # @return [void]
      def cmd_help(args)
        if args.empty?
          display_general_help
        else
          display_command_help(args[0])
        end
      end

      # Utilities: Show command history
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_history(_args)
        history = Readline::HISTORY.to_a.last(20)
        history.each_with_index do |line, i|
          puts "#{i + 1}. #{line}"
        end
      end

      # Utilities: Clear screen
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_clear(_args)
        print "\e[2J\e[H"
      end

      # Utilities: Show configuration
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_config(_args)
        puts OutputFormatter.colorize("Current Configuration:", :cyan)
        @config.each do |key, value|
          puts "  #{key}: #{value}"
        end
      end

      # Utilities: Show quick statistics
      #
      # @param _args [Array<String>] Command arguments (unused)
      # @return [void]
      def cmd_stats(_args)
        stats = @repository.statistics

        if @config[:icons]
          puts EnhancedFormatter.format_stats_enhanced(stats)
        else
          puts OutputFormatter.format_stats(stats, detailed: false)
        end
      end

      # Show class details
      #
      # @param qname [String] Qualified class name
      # @return [void]
      def show_class(qname) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        cls = @repository.find_class(qname)

        unless cls
          puts OutputFormatter.error("Class not found: #{qname}")
          return
        end

        if @config[:icons]
          puts EnhancedFormatter.format_class_details_enhanced(cls)
        else
          puts OutputFormatter.colorize("Class: #{qname}", :cyan)
          puts "=" * 50
          puts ""
          puts "Name: #{cls.name}"

          if cls.respond_to?(:attributes) && cls.attributes &&
              !cls.attributes.empty?
            puts ""
            puts OutputFormatter.colorize("Attributes:", :yellow)
            cls.attributes.each do |attr|
              puts "  - #{attr.name}: #{attr.type}"
            end
          end
        end
      end

      # Show package details
      #
      # @param path [String] Package path
      # @return [void]
      def show_package(path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        path = resolve_path(path)
        pkg = @repository.find_package(path)

        unless pkg
          puts OutputFormatter.error("Package not found: #{path}")
          return
        end

        puts OutputFormatter.colorize("Package: #{path}", :cyan)
        puts "=" * 50
        puts ""
        puts "Name: #{pkg.name}"
        puts ""

        classes = @repository.classes_in_package(path)
        puts OutputFormatter.colorize("Classes (#{classes.size}):", :yellow)
        classes.each do |cls|
          icon = @config[:icons] ? "#{EnhancedFormatter::ICONS[:class]} " : ""
          puts "  #{icon}#{cls.name}"
        end
      end

      # Show numbered result from last search
      #
      # @param number [Integer] Result number (1-indexed)
      # @return [void]
      def show_numbered_result(number) # rubocop:disable Metrics/MethodLength
        if @last_results.nil? || @last_results.empty?
          puts OutputFormatter.warning("No previous results")
          return
        end

        index = number - 1
        if index.negative? || index >= @last_results.size
          puts OutputFormatter.error("Invalid result number: #{number}")
          return
        end

        item = @last_results[index]
        show_class(item)
      end

      # Display search results
      #
      # @param results [Hash] Search results by type
      # @return [void]
      def display_search_results(results) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        results.each do |type, items| # rubocop:disable Metrics/BlockLength
          next if items.empty?

          puts ""
          puts OutputFormatter.colorize(
            "#{type.to_s.capitalize} Results (#{items.size}):", :cyan
          )

          case type
          when :class
            @last_results = items
            items.each_with_index do |qname, i|
              icon = if @config[:icons]
                       "#{EnhancedFormatter::ICONS[:class]} "
                     else
                       ""
                     end
              puts "  #{i + 1}. #{icon}#{qname}"
            end
            puts ""
            puts "Use 'show NUMBER' to view details"
          when :attribute
            items.each do |item|
              puts "  - #{item[:class_name]}::#{item[:attribute_name]} : " \
                   "#{item[:type]}"
            end
          when :association
            items.each do |item|
              icon = if @config[:icons]
                       "#{EnhancedFormatter::ICONS[:association]} "
                     else
                       ""
                     end
              puts "  #{icon}#{item[:source]} → #{item[:target]}"
            end
          end
        end
      end

      # Add bookmark
      #
      # @param name [String] Bookmark name
      # @return [void]
      def bookmark_add(name)
        if name.nil? || name.empty?
          puts OutputFormatter.warning("Usage: bookmark add NAME")
          return
        end

        target = @last_results&.first || @current_path
        @bookmarks[name] = target
        puts OutputFormatter.success("Bookmark '#{name}' added: #{target}")
      end

      # List bookmarks
      #
      # @return [void]
      def bookmark_list # rubocop:disable Metrics/MethodLength
        if @bookmarks.empty?
          puts "No bookmarks"
        else
          puts OutputFormatter.colorize("Bookmarks:", :cyan)
          @bookmarks.each do |name, target|
            icon = if @config[:icons]
                     "#{EnhancedFormatter::ICONS[:favorite]} "
                   else
                     ""
                   end
            puts "  #{icon}#{name} → #{target}"
          end
        end
      end

      # Jump to bookmark
      #
      # @param name [String] Bookmark name
      # @return [void]
      def bookmark_go(name) # rubocop:disable Metrics/MethodLength
        unless @bookmarks.key?(name)
          puts OutputFormatter.error("Bookmark not found: #{name}")
          return
        end

        target = @bookmarks[name]
        if @repository.find_package(target)
          unless @path_history.last == @current_path
            @path_history << @current_path
          end
          @current_path = target
          puts "Changed to: #{target}"
        else
          puts OutputFormatter.warning(
            "Bookmark target no longer exists: #{target}",
          )
        end
      end

      # Remove bookmark
      #
      # @param name [String] Bookmark name
      # @return [void]
      def bookmark_remove(name)
        if @bookmarks.delete(name)
          puts OutputFormatter.success("Bookmark '#{name}' removed")
        else
          puts OutputFormatter.error("Bookmark not found: #{name}")
        end
      end

      # Export results to CSV
      #
      # @param file_path [String] Output file path
      # @return [void]
      def export_csv(file_path)
        require "csv"

        CSV.open(file_path, "w") do |csv|
          csv << ["Qualified Name"]
          @last_results.each do |qname|
            csv << [qname]
          end
        end

        puts OutputFormatter.success("Exported #{@last_results.size} " \
                                     "results to #{file_path}")
      end

      # Export results to JSON
      #
      # @param file_path [String] Output file path
      # @return [void]
      def export_json(file_path)
        require "json"

        File.write(file_path, JSON.pretty_generate(@last_results))
        puts OutputFormatter.success("Exported #{@last_results.size} " \
                                     "results to #{file_path}")
      end

      # Export results to YAML
      #
      # @param file_path [String] Output file path
      # @return [void]
      def export_yaml(file_path)
        require "yaml"

        File.write(file_path, @last_results.to_yaml)
        puts OutputFormatter.success("Exported #{@last_results.size} " \
                                     "results to #{file_path}")
      end

      # Display general help
      #
      # @return [void]
      def display_general_help # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        puts OutputFormatter.colorize("Available Commands:", :cyan)
        puts ""

        puts OutputFormatter.colorize("Navigation:", :yellow)
        puts "  cd PATH           Change to package path"
        puts "  pwd               Print current path"
        puts "  ls [PATH]         List packages"
        puts "  tree [PATH]       Show package tree"
        puts "  up                Go to parent package"
        puts "  root              Go to ModelRoot"
        puts "  back              Go to previous location"
        puts ""

        puts OutputFormatter.colorize("Query:", :yellow)
        puts "  find CLASS        Find class (fuzzy search)"
        puts "  show class QNAME  Show class details"
        puts "  show package PATH Show package details"
        puts "  show NUMBER       Show numbered result"
        puts "  search QUERY      Full-text search"
        puts "  ? QUERY           Alias for search"
        puts ""

        puts OutputFormatter.colorize("Bookmarks:", :yellow)
        puts "  bookmark add NAME  Bookmark current location"
        puts "  bookmark list      List bookmarks"
        puts "  bookmark go NAME   Jump to bookmark"
        puts "  bookmark rm NAME   Remove bookmark"
        puts "  bm NAME            Quick jump"
        puts ""

        puts OutputFormatter.colorize("Utilities:", :yellow)
        puts "  help [COMMAND]    Show help"
        puts "  history           Show command history"
        puts "  clear             Clear screen"
        puts "  config            Show configuration"
        puts "  stats             Show statistics"
        puts "  exit, quit, q     Exit shell"
      end

      # Display command-specific help
      #
      # @param command [String] Command name
      # @return [void]
      def display_command_help(command)
        # Command-specific help would go here
        puts "Help for '#{command}' not yet implemented"
        puts "Use 'help' for general help"
      end

      # Resolve path relative to current location
      #
      # @param path [String] Path to resolve
      # @return [String] Resolved path
      def resolve_path(path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        return path if path.start_with?("ModelRoot")
        return @current_path if path == "."
        return "ModelRoot" if path == "/"

        if path.start_with?("../")
          # Go up and then navigate
          parts = @current_path.split("::")
          path.scan("../").each { parts.pop }
          remaining = path.gsub(/^(\.\.\/)+/, "")
          new_path = parts + remaining.split("/")
          new_path.join("::")
        elsif path.start_with?("./")
          # Relative to current
          "#{@current_path}::#{path[2..]}"
        else
          # Append to current
          @current_path == "ModelRoot" ? path : "#{@current_path}::#{path}"
        end
      end
    end
  end
end
