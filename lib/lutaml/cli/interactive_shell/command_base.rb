# frozen_string_literal: true

module Lutaml
  module Cli
    class InteractiveShell
      class CommandBase
        attr_reader :shell

        def initialize(shell)
          @shell = shell
        end

        def repository = shell.repository
        def current_path = shell.current_path
        def current_path=(path)
          shell.instance_variable_set(:@current_path, path)
        end
        def config = shell.config
        def bookmarks = shell.bookmarks
        def last_results = shell.last_results
        def last_results=(results)
          shell.instance_variable_set(:@last_results, results)
        end
        def path_history = shell.path_history
      end
    end
  end
end
