# frozen_string_literal: true

require "stringio"

module Expressir
  # Helper module for capturing console output in tests
  module ConsoleHelper
    # Capture stdout during block execution
    # @yield Block to execute
    # @return [String] Captured stdout content
    def capture_stdout
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    # Capture stderr during block execution
    # @yield Block to execute
    # @return [String] Captured stderr content
    def capture_stderr
      original_stderr = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = original_stderr
    end
  end
end
