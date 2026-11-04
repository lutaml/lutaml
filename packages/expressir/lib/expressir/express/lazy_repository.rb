# frozen_string_literal: true

require "liquid"

module Expressir
  module Express
    # Lazy read path over a compiled-set artifact (M2 slice 2,
    # TODO.parity-ee/19): schemas hydrate individually, on first touch,
    # instead of the whole repository at once. Metanorma schema-doc
    # rendering touches one schema per page — the lazy repository makes
    # that pay: one hydration per page, not one per schema in the set.
    #
    # Duck-types the read surface of Model::Repository used by
    # rendering (schemas, files, each, size, children). Anything beyond
    # the read surface should wait for eager hydration via
    # #to_eager (returns a real Model::Repository).
    class LazyRepository
      attr_reader :set_path

      # @param set_path [String] compiled-set artifact path
      # @param read_paths [Hash{String => String}] wire path => source path
      def initialize(set_path, read_paths = {})
        @set_path = set_path
        @set = Core.lazy_set(set_path)
        @read_paths = read_paths
        @wire_paths = @set.wire_paths
        @mutex = Mutex.new
        @file_cache = {}
        @hydration_count = 0
      end

      # Wire paths in artifact order — no hydration.
      # @return [Array<String>]
      def wire_paths
        @wire_paths.dup
      end

      # Files in artifact order, each wrapped so it hydrates on first
      # use. The file is the hydration grain: an artifact stores wire
      # JSON per source file.
      # @return [Array<LazyFile>]
      def files
        @wire_paths.map { |wire_path| file_by_wire_path(wire_path) }
      end

      # Hydrated (or hydrating) file for one wire path.
      def file_by_wire_path(wire_path)
        @mutex.synchronize do
          @file_cache[wire_path] ||= LazyFile.new(wire_path) do
            hydrate(wire_path)
          end
        end
      end

      # Schemas across all files. EAGER by definition: it hydrates
      # every file. Lazy callers iterate #files, or render through
      # #to_liquid, which keeps per-file hydration lazy.
      # @return [Array<Declarations::Schema>]
      def schemas
        files.map(&:__target__).flat_map(&:schemas).compact
      end

      # Liquid binding for metanorma (M2): returns a Drop whose
      # `schemas` is a lazy per-file list — each entry hydrates only
      # its own file when the template touches it. Schema count per
      # file is unknown until hydration, so the Drop presents one
      # entry per FILE; single-schema files (the corpus norm) render
      # identically to the eager path.
      def to_liquid
        LazyRepositoryDrop.new(self)
      end

      # How many files have actually been hydrated (observability for
      # the laziness contract).
      def hydration_count
        @hydration_count
      end

      # Hydrate everything and return a real Model::Repository — the
      # escape hatch for callers needing the full read surface.
      def to_eager
        repo = Model::Repository.new
        repo.files = files.map(&:__target__)
        repo
      end

      def each(&)
        files.each(&)
      end

      def size
        @wire_paths.size
      end

      def children
        schemas
      end

      # The read path on disk for a wire path (may be nil when the
      # caller did not supply source paths).
      def read_path_for(wire_path)
        @read_paths[wire_path]
      end

      def matches_sources?
        @set.matches_sources(@read_paths.dup) == true
      end

      private

      def hydrate(wire_path)
        @mutex.synchronize do
          _wire, model = @set.hydrate_one(wire_path)
          @hydration_count += 1
          model
        end
      end
    end

    # Liquid::Drop over a LazyRepository: `schemas` enumerates lazy
    # per-file entries; touching an entry hydrates that file and
    # presents its schemas (single-schema files present the schema
    # itself, matching the eager Drop's element contract).
    class LazyRepositoryDrop < ::Liquid::Drop
      def initialize(repo)
        @repo = repo
        super()
      end

      def schemas
        @repo.files.map do |file|
          LazyFileDrop.new(file)
        end
      end

      def size
        @repo.size
      end
    end

    # Per-file lazy drop: hydrates on first access, then presents the
    # file's single schema directly (or the schema list for
    # multi-schema files).
    class LazyFileDrop < ::Liquid::Drop
      def initialize(file)
        @file = file
        super()
      end

      def __file__
        @file.__target__
      end

      def method_missing(name, *, &)
        schemas = __file__.schemas
        if schemas.size == 1
          schemas.first.public_send(name, *, &)
        else
          __file__.public_send(name, *, &)
        end
      end

      def respond_to_missing?(name, include_private = false)
        __file__.respond_to?(name, include_private) ||
          __file__.schemas.first.respond_to?(name, include_private)
      end
    end

    # Stands in for a Model::ExpFile until first method access, then
    # hydrates through the block and forwards everything.
    class LazyFile
      def initialize(wire_path, &hydrator)
        @wire_path = wire_path
        @hydrator = hydrator
        @mutex = Mutex.new
        @target = nil
      end

      attr_reader :wire_path

      # The real Schema, hydrating on first call.
      def __target__
        @mutex.synchronize do
          @__target__ ||= @hydrator.call
        end
      end

      def method_missing(name, *, &)
        __target__.public_send(name, *, &)
      end

      def respond_to_missing?(name, include_private = false)
        __target__.respond_to?(name, include_private)
      end

      # Identity through the wrapper: rendering compares and groups by
      # class/is_a?, which the real file answers.
      def is_a?(klass)
        super || __target__.is_a?(klass)
      end

      def instance_of?(klass)
        __target__.instance_of?(klass)
      end

      def class
        __target__.class
      end
    end
  end
end
