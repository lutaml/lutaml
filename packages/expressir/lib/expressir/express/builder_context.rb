# frozen_string_literal: true

module Expressir
  module Express
    # Value object carrying the per-build context that Builder needs to
    # attach source info to model elements.
    #
    # Stored as a thread-local by Builder.build_with_remarks so that recursive
    # build calls can read `Builder.source` / `Builder.include_source` without
    # the module mutating class-level state. Thread-local means concurrent
    # builds in different threads don't corrupt each other; the save/restore
    # pattern in build_with_remarks means nested builds are reentrant.
    class BuilderContext
      attr_reader :source, :include_source

      def initialize(source:, include_source:)
        @source = source
        @include_source = include_source
      end
    end
  end
end
