# frozen_string_literal: true

require_relative "command_base"
require_relative "../enhanced_formatter"

module Lutaml
  module Cli
    class InteractiveShell
      class HelpDisplay < CommandBase
        def display_welcome
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

          stats = repository.statistics
          puts "Repository loaded:"
          puts "  #{stats[:total_packages]} packages, " \
               "#{stats[:total_classes]} classes"
          puts ""
        end

        def cmd_help(args)
          if args.empty?
            display_general_help
          else
            display_command_help(args[0])
          end
        end

        def cmd_history(_args)
          history = Readline::HISTORY.to_a.last(20)
          history.each_with_index do |line, i|
            puts "#{i + 1}. #{line}"
          end
        end

        def cmd_clear(_args)
          print "\e[2J\e[H"
        end

        def cmd_config(_args)
          puts OutputFormatter.colorize("Current Configuration:", :cyan)
          config.each do |key, value|
            puts "  #{key}: #{value}"
          end
        end

        def cmd_stats(_args)
          stats = repository.statistics

          if config[:icons]
            puts EnhancedFormatter.format_stats_enhanced(stats)
          else
            puts OutputFormatter.format_stats(stats, detailed: false)
          end
        end

        def display_general_help
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

        def display_command_help(command)
          puts "Help for '#{command}' not yet implemented"
          puts "Use 'help' for general help"
        end
      end
    end
  end
end
