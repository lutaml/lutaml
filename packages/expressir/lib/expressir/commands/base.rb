require "etc"

module Expressir
  module Commands
    class Base
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      # The parallel-parse worker count for the validate family: the
      # explicit --jobs value, or every core (issue #584). The
      # ParallelFiles facility degrades to sequential where fork is
      # unavailable (e.g. Windows).
      def jobs_count
        jobs = options[:jobs]
        return jobs if jobs.is_a?(Integer) && jobs >= 1

        Etc.nprocessors
      end

      # Common utilities that all commands might need
      def say(message)
        # Use instance variable for testability - if output is set, use it
        if defined?(@output) && @output
          @output.puts(message)
        else
          puts(message)
        end
      end

      def exit_with_error(message, _exit_code = 1)
        raise Expressir::CommandError.new(message)
      end
    end
  end
end
