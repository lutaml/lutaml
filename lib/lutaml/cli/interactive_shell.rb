# frozen_string_literal: true

require "readline"
require "pathname"
require_relative "enhanced_formatter"
require_relative "../uml_repository/repository"
require_relative "interactive_shell/command_base"
require_relative "interactive_shell/navigation_commands"
require_relative "interactive_shell/query_commands"
require_relative "interactive_shell/bookmark_commands"
require_relative "interactive_shell/export_handler"
require_relative "interactive_shell/help_display"

module Lutaml
  module Cli
    class InteractiveShell
      HISTORY_FILE = File.expand_path("~/.lutaml-xmi-history")
      MAX_HISTORY = 1000

      attr_reader :repository, :current_path, :config, :bookmarks,
                  :last_results, :path_history

      def initialize(lur_path_or_repo, config: nil)
        @config = {
          color: true,
          icons: true,
          show_counts: true,
          page_size: 50,
        }.merge(config || {})

        if lur_path_or_repo.is_a?(String)
          OutputFormatter.progress("Loading repository")
          @repository = Lutaml::UmlRepository::Repository.from_package(lur_path_or_repo)
          OutputFormatter.progress_done
        else
          @repository = lur_path_or_repo
        end

        @current_path = "ModelRoot"
        @bookmarks = {}
        @last_results = nil
        @path_history = ["ModelRoot"]
        @running = false

        @navigation = NavigationCommands.new(self)
        @query = QueryCommands.new(self)
        @bookmarks_cmd = BookmarkCommands.new(self)
        @export = ExportHandler.new(self)
        @help = HelpDisplay.new(self)

        setup_readline
        load_history
      end

      def start
        @running = true
        @help.display_welcome

        while @running
          begin
            input = Readline.readline(prompt, true)
            break if input.nil?
            next if input.strip.empty?

            if Readline::HISTORY.length > 1 && Readline::HISTORY[-2] == input
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

      COMMAND_DISPATCH = {
        # Navigation
        "cd" => :@navigation, "pwd" => :@navigation,
        "ls" => :@navigation, "list" => :@navigation,
        "tree" => :@navigation, "up" => :@navigation,
        "root" => :@navigation, "back" => :@navigation,
        # Query
        "find" => :@query, "f" => :@query,
        "show" => :@query, "s" => :@query,
        "search" => :@query, "?" => :@query,
        "results" => :@query,
        # Bookmarks
        "bookmark" => :@bookmarks_cmd, "bm" => :@bookmarks_cmd,
        # Export
        "export" => :@export,
        # Utilities
        "help" => :@help, "h" => :@help,
        "history" => :@help,
        "clear" => :@help, "cls" => :@help,
        "config" => :@help,
        "stats" => :@help,
      }.freeze

      METHOD_MAP = {
        "cd" => :cmd_cd, "pwd" => :cmd_pwd,
        "ls" => :cmd_ls, "list" => :cmd_ls,
        "tree" => :cmd_tree, "up" => :cmd_up,
        "root" => :cmd_root, "back" => :cmd_back,
        "find" => :cmd_find, "f" => :cmd_find,
        "show" => :cmd_show, "s" => :cmd_show,
        "search" => :cmd_search, "?" => :cmd_search,
        "results" => :cmd_results,
        "bookmark" => :cmd_bookmark, "bm" => :cmd_bookmark,
        "export" => :cmd_export,
        "help" => :cmd_help, "h" => :cmd_help,
        "history" => :cmd_history,
        "clear" => :cmd_clear, "cls" => :cmd_clear,
        "config" => :cmd_config,
        "stats" => :cmd_stats,
      }.freeze

      def execute_command(input)
        parts = input.split(/\s+/)
        command = parts[0].downcase
        args = parts[1..]

        if command == "exit" || command == "quit" || command == "q"
          @running = false
          return
        end

        handler_var = COMMAND_DISPATCH[command]
        method_name = METHOD_MAP[command]

        if handler_var && method_name
          instance_variable_get(handler_var).send(method_name, args)
        else
          puts OutputFormatter.warning("Unknown command: #{command}")
          puts "Type 'help' for available commands"
        end
      end

      # Delegate methods for backward compatibility with tests
      def cmd_cd(args) = @navigation.cmd_cd(args)
      def cmd_pwd(args) = @navigation.cmd_pwd(args)
      def cmd_ls(args) = @navigation.cmd_ls(args)
      def cmd_tree(args) = @navigation.cmd_tree(args)
      def cmd_up(args) = @navigation.cmd_up(args)
      def cmd_root(args) = @navigation.cmd_root(args)
      def cmd_back(args) = @navigation.cmd_back(args)
      def resolve_path(path) = @navigation.resolve_path(path)
      def cmd_find(args) = @query.cmd_find(args)
      def cmd_show(args) = @query.cmd_show(args)
      def cmd_search(args) = @query.cmd_search(args)
      def cmd_results(args) = @query.cmd_results(args)
      def show_class(qname) = @query.show_class(qname)
      def show_package(path) = @query.show_package(path)
      def show_numbered_result(number) = @query.show_numbered_result(number)
      def display_search_results(results) = @query.display_search_results(results)
      def cmd_bookmark(args) = @bookmarks_cmd.cmd_bookmark(args)
      def bookmark_add(name) = @bookmarks_cmd.bookmark_add(name)
      def bookmark_list = @bookmarks_cmd.bookmark_list
      def bookmark_go(name) = @bookmarks_cmd.bookmark_go(name)
      def bookmark_remove(name) = @bookmarks_cmd.bookmark_remove(name)
      def cmd_export(args) = @export.cmd_export(args)
      def export_csv(path) = @export.export_csv(path)
      def export_json(path) = @export.export_json(path)
      def export_yaml(path) = @export.export_yaml(path)
      def display_welcome = @help.display_welcome
      def display_general_help = @help.display_general_help
      def display_command_help(cmd) = @help.display_command_help(cmd)
      def cmd_help(args) = @help.cmd_help(args)
      def cmd_history(args) = @help.cmd_history(args)
      def cmd_clear(args) = @help.cmd_clear(args)
      def cmd_config(args) = @help.cmd_config(args)
      def cmd_stats(args) = @help.cmd_stats(args)

      def prompt
        path_display = @current_path == "ModelRoot" ? "/" : "/#{@current_path}"
        prompt_text = "lutaml[#{path_display}]> "

        if @config[:color] && $stdout.tty?
          OutputFormatter.colorize(prompt_text, :green)
        else
          prompt_text
        end
      end

      def setup_readline
        Readline.completion_proc = proc { |word| complete_command(word) }
        Readline.completion_append_character = " "
      end

      def load_history
        return unless File.exist?(HISTORY_FILE)

        File.readlines(HISTORY_FILE).each do |line|
          Readline::HISTORY.push(line.chomp)
        end
      rescue StandardError => e
        warn "Warning: Could not load history: #{e.message}" if ENV["DEBUG"]
      end

      def save_history
        history_lines = Readline::HISTORY.to_a.last(MAX_HISTORY)
        File.write(HISTORY_FILE, history_lines.join("\n"))
      rescue StandardError => e
        warn "Warning: Could not save history: #{e.message}"
      end

      def complete_command(word)
        %w[
          cd pwd ls list tree up root back
          find show search
          bookmark bm
          results export
          help history clear config stats exit quit
        ].grep(/^#{Regexp.escape(word)}/)
      end
    end
  end
end
