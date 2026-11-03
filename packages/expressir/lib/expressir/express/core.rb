# frozen_string_literal: true

require "json"

module Expressir
  module Express
    # Ruby bridge to the expressir-core Rust crate (parse + model
    # extraction). Available when the native extension is built;
    # callers fall back to the pure-Ruby parser otherwise.
    #
    module Core
      NATIVE_AVAILABLE = begin
        require "expressir/expressir_core"
        true
      rescue LoadError
        begin
          # Platform gems carry the fat-binary layout
          # (lib/expressir/<major.minor>/expressir_core.so); rubygems
          # does not resolve versioned dirs under a nested require path,
          # so the version segment is explicit - same contract as
          # parsanol's loader.
          ruby_version = RUBY_VERSION.split(".").take(2).join(".")
          require "expressir/#{ruby_version}/expressir_core"
          true
        rescue LoadError
          begin
            require_relative "../../../ext/expressir_core/expressir_core"
            true
          rescue LoadError
            false
          end
        end
      end

      # Parse EXPRESS source and return the model as a plain Hash in the
      # lutaml wire shape (to_hash-compatible), ready for
      # Expressir::Model::ExpFile.from_hash. `path` is the relative file
      # path used for file/base_path wiring in the model.
      def self.parse_to_model_hash(source, path)
        JSON.parse(::Expressir::Core.parse_to_model_hash(source, path))
      end

      # Scan remarks (issue #20): an Array of Hashes mirroring
      # RemarkScanner::Remark's fields (position, end_position, line,
      # text, tag, format), straight from the Rust scanner.
      def self.scan_remarks(source)
        ::Expressir::Core.scan_remarks(source)
      end

      # Parse EXPRESS source into the hydrated model directly: the
      # extension walks the wire definition once and constructs every
      # node through Serializable.instantiate (lutaml-model's fast
      # bulk constructor). Falls back to the hash path when either
      # the extension or the lutaml-model instantiate API is absent.
      def self.parse_to_model(source, path)
        unless ::Expressir::Core.respond_to?(:parse_to_model) &&
            Model::ExpFile.respond_to?(:instantiate)
          raise NotImplementedError,
                "direct model construction unavailable; use parse_to_model_hash"
        end

        ::Expressir::Core.parse_to_model(source, path)
      end

      # Lazy handle over a compiled-set artifact (M2): `wire_paths`
      # lists the set's files without hydrating anything; `hydrate_one`
      # builds a single file's model on demand. Renderers that touch
      # one schema per page hydrate one schema per page instead of the
      # whole repository.
      def self.lazy_set(path)
        unless NATIVE_AVAILABLE
          raise NotImplementedError,
                "lazy set unavailable without the native extension"
        end
        unless ::Expressir::Core.const_defined?(:Set) &&
            ::Expressir::Core::Set.method_defined?(:hydrate_one)
          raise NotImplementedError, "lazy set unavailable; ext too old"
        end

        ::Expressir::Core::Set.open(path)
      end

      # Compile many files concurrently: jobs are [read_path,
      # wire_path] pairs; the block receives (wire_path, model, error)
      # per job in completion order. Workers run on native threads, so
      # they keep compiling while the block hydrates and post-processes
      # each model.
      def self.parse_batch(jobs, workers: 0)
        unless ::Expressir::Core.respond_to?(:const_defined?) &&
            ::Expressir::Core.const_defined?(:BatchStream)
          raise NotImplementedError,
                "batch compile unavailable; parse files individually"
        end

        stream = ::Expressir::Core::BatchStream.start(jobs, workers)
        while (item = stream.next)
          path, model, error = item
          yield(path, model, error)
        end
      end
    end
  end
end
