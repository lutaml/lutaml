# frozen_string_literal: true

module Lutaml
  module Cli
    class InteractiveShell
      class HelpDisplay < CommandBase
        def display_welcome
          puts <<~WELCOME
            #{OutputFormatter.colorize('╔═══════════════════════════════════════╗', :cyan)}
            #{OutputFormatter.colorize('║  LutaML Interactive Shell (REPL)     ║', :cyan)}
            #{OutputFormatter.colorize('╚═══════════════════════════════════════╝', :cyan)}

            Type 'help' for available commands, 'exit' to quit

          WELCOME

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

        HELP_TEXT = <<~HELP
          Available Commands:

          Navigation:
            cd PATH           Change to package path
            pwd               Print current path
            ls [PATH]         List packages
            tree [PATH]       Show package tree
            up                Go to parent package
            root              Go to ModelRoot
            back              Go to previous location

          Query:
            find CLASS        Find class (fuzzy search)
            show class QNAME  Show class details
            show package PATH Show package details
            show NUMBER       Show numbered result
            search QUERY      Full-text search
            ? QUERY           Alias for search

          Bookmarks:
            bookmark add NAME  Bookmark current location
            bookmark list      List bookmarks
            bookmark go NAME   Jump to bookmark
            bookmark rm NAME   Remove bookmark
            bm NAME            Quick jump

          Utilities:
            help [COMMAND]    Show help
            history           Show command history
            clear             Clear screen
            config            Show configuration
            stats             Show statistics
            exit, quit, q     Exit shell
        HELP

        def display_general_help
          puts OutputFormatter.colorize(HELP_TEXT, :cyan)
        end

        def display_command_help(command)
          puts "Help for '#{command}' not yet implemented"
          puts "Use 'help' for general help"
        end
      end
    end
  end
end
