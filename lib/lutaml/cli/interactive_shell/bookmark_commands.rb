# frozen_string_literal: true

require_relative "command_base"
require_relative "../enhanced_formatter"

module Lutaml
  module Cli
    class InteractiveShell
      class BookmarkCommands < CommandBase
        def cmd_bookmark(args)
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
            bookmark_go(subcommand)
          end
        end

        def bookmark_add(name)
          if name.nil? || name.empty?
            puts OutputFormatter.warning("Usage: bookmark add NAME")
            return
          end

          target = last_results&.first || current_path
          bookmarks[name] = target
          puts OutputFormatter.success("Bookmark '#{name}' added: #{target}")
        end

        def bookmark_list
          if bookmarks.empty?
            puts "No bookmarks"
          else
            puts OutputFormatter.colorize("Bookmarks:", :cyan)
            bookmarks.each do |name, target|
              icon = config[:icons] ? "#{EnhancedFormatter::ICONS[:favorite]} " : ""
              puts "  #{icon}#{name} → #{target}"
            end
          end
        end

        def bookmark_go(name)
          unless bookmarks.key?(name)
            puts OutputFormatter.error("Bookmark not found: #{name}")
            return
          end

          target = bookmarks[name]
          if repository.find_package(target)
            push_path_history
            self.current_path = target
            puts "Changed to: #{target}"
          else
            puts OutputFormatter.warning(
              "Bookmark target no longer exists: #{target}",
            )
          end
        end

        def bookmark_remove(name)
          if bookmarks.delete(name)
            puts OutputFormatter.success("Bookmark '#{name}' removed")
          else
            puts OutputFormatter.error("Bookmark not found: #{name}")
          end
        end

        private

        def push_path_history
          return if path_history.last == current_path

          path_history << current_path
        end
      end
    end
  end
end
