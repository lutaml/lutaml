# frozen_string_literal: true

require "digest"
require "json"
require "parsanol"

module Expressir
  module Express
    # Public-facing parser facade.
    #
    # Three concerns were split out (TODO.bugs/09):
    # - Grammar rules → {Grammar::Parser} (~250 Parsanol rules)
    # - Schema-block splitting → {SchemaBlockScanner}
    # - I/O orchestration → this class (from_file, from_exp, etc.)
    #
    # The facade delegates grammar work to Grammar::Parser and block
    # extraction to SchemaBlockScanner. All public methods remain
    # backward-compatible.
    class Parser
      # Threshold for using memory-bounded fresh parse (bytes)
      LARGE_FILE_THRESHOLD = 1024 * 1024 # 1 MB

      class << self
        # Delegate grammar-level queries to Grammar::Parser.
        def native_available? = Grammar::Parser.native_available?
        def cached_parser = Grammar::Parser.cached_parser
        def cached_grammar_json = Grammar::Parser.cached_grammar_json
        def cached_schema_grammar_json = Grammar::Parser.cached_schema_grammar_json
        def parse_native(source) = Grammar::Parser.parse_native(source)
        def clear_parser_cache = Grammar::Parser.clear_parser_cache
      end

      # UTF-8 BOM byte sequence (EF BB BF). Some editors prepend this
      # to EXPRESS files; the parser fails because SCHEMA isn't at byte 0.
      def self.strip_bom(source)
        bytes = source.b
        return source unless bytes.bytesize >= 3 &&
          bytes.getbyte(0) == 0xEF &&
          bytes.getbyte(1) == 0xBB &&
          bytes.getbyte(2) == 0xBF

        bytes.byteslice(3..).force_encoding(source.encoding)
      end
      private_class_method :strip_bom

      # Parses Express file into an Express model.
      # @param file [String] Express file path
      # @param skip_references [Boolean] skip resolving references
      # @param include_source [Boolean] attach original source code to model elements
      # @param use_native [Boolean] use native parser (default: true when available)
      # @param use_core [Boolean] use the Rust core parse path
      #   (default: true when the expressir-core extension is available;
      #   produces a byte-identical model to the Ruby path — see
      #   parser_core_parity_spec)
      # @return [Model::ExpFile] ExpFile containing parsed schemas
      # @raise [Error::SchemaParseFailure] if the schema file fails to parse
      def self.from_file(file, skip_references: nil, include_source: nil,
                         root_path: nil, use_native: nil,
                         use_core: nil, dialect: nil) # rubocop:disable Metrics/AbcSize
        Dialect.normalize(dialect)
        # use_native: false pins the Ruby grammar path; the core path
        # must not silently take over that request.
        use_core = Core::NATIVE_AVAILABLE if use_core.nil? && use_native != false
        if use_core && Core::NATIVE_AVAILABLE
          return from_file_core(file, skip_references: skip_references,
                                      include_source: include_source,
                                      root_path: root_path)
        end

        Expressir::Benchmark.measure_file(file) do
          source = strip_bom(File.read(file))

          schema_file = root_path ? Pathname.new(file.to_s).relative_path_from(root_path).to_s : file.to_s

          use_native = Grammar::Parser.native_available? if use_native.nil?

          begin
            ast = if use_native && Grammar::Parser.native_available?
                    begin
                      Grammar::Parser.parse_native(source)
                    rescue StandardError
                      Grammar::Parser.parse_ruby(source)
                    end
                  else
                    Grammar::Parser.parse_ruby(source)
                  end
          rescue Parsanol::ParseFailed => e
            raise Error::SchemaParseFailure.new(schema_file, e)
          end

          exp_file = ::Expressir::Express::Builder.build_with_remarks(ast, source: source,
                                                                           include_source: include_source)

          # issue #537 part 2: a remark-only fragment (no SCHEMA
          # wrapper — e.g. conversion artifacts) parses to an empty
          # model; report it as the missing schema it is rather than a
          # grammar dump.
          if Array(exp_file&.schemas).empty?
            raise Expressir::SchemaNotFoundError,
                  "no schema found in #{schema_file} (remark-only or empty input)"
          end

          transfer_header_to_schema(exp_file, source)

          exp_file.path = schema_file
          exp_file.schemas.each do |schema|
            schema.file = schema_file
            schema.file_basename = File.basename(schema_file, ".exp")
          end

          unless skip_references
            Expressir::Benchmark.measure_references do
              ResolveReferencesModelVisitor.new.visit(exp_file)
            end
          end

          exp_file
        end
      end

      # Parses Express files into an Express model.
      # @param files [Array<String>] Express file paths
      # @param skip_references [Boolean] skip resolving references
      # @param include_source [Boolean] attach original source code to model elements
      # @param use_native [Boolean] use native parser (default: true when available)
      # @yield [filename, schemas, error] Optional block called for each file
      # @return [Model::Repository] Repository containing all parsed ExpFiles
      def self.from_files(files, skip_references: nil, include_source: nil,
                          root_path: nil, use_native: nil, max_processes: nil,
                          compiled_set: nil, dialect: nil, &progress)
        Dialect.normalize(dialect)
        set_path = compiled_set || ENV.fetch("EXPRESSIR_COMPILED_SET", nil)
        if set_path && core_set_available?
          repo = from_compiled_set(set_path, files,
                                   skip_references: skip_references,
                                   include_source: include_source,
                                   root_path: root_path)
          return repo if repo
        end

        # EXPRESSIR_BATCH=0 escapes the native batch workers: their
        # Rust threads crash the process under some loads (SIGILL in
        # the mpmc recv park — see GH batch-crash report); sequential
        # parsing is slower but proven stable.
        batch_disabled = ENV["EXPRESSIR_BATCH"] == "0"
        all_exp_files = if batch_available? && !batch_disabled && files.size > 1
                          from_files_batch(
                            files, include_source: include_source,
                                   root_path: root_path,
                                   max_processes: max_processes,
                                   compiled_set_out: set_path
                          ) do |file, exp_file, error|
                            progress&.call(file, exp_file&.schemas, error)
                          end
                        elsif ParallelFiles.sequential?(files, max_processes)
                          parse_files_sequentially(
                            files, skip_references: skip_references, include_source: include_source,
                                   root_path: root_path, use_native: use_native
                          ) do |file, exp_file, error|
                            progress&.call(file, exp_file&.schemas, error)
                          end
                        else
                          ParallelFiles.run(
                            files,
                            max_processes: max_processes,
                            parse: lambda do |file|
                              from_file(file, skip_references: true, root_path: root_path,
                                              use_native: use_native)
                            end,
                          ) do |file, exp_file, error|
                            progress&.call(file, exp_file&.schemas, error)
                          end
                        end

        repository = build_repository(all_exp_files, skip_references: skip_references)
        if set_path && !skip_references && !File.exist?(set_path) &&
            !all_exp_files.include?(nil)
          if core_set_available?
            write_compiled_set(set_path, files, all_exp_files, root_path)
          else
            warn "expressir: compiled-set write to #{set_path} skipped: " \
                 "the expressir-core native extension is unavailable"
          end
        end
        if set_path && !skip_references && File.exist?(set_path)
          files = all_exp_files.compact
          RefsOverlay.write(set_path, files)
          graph = Model::Indexes::ItemGraph.new(repository)
          repository.item_graph = graph
          require "json"
          File.write("#{set_path}.graph.json", JSON.generate(graph.tables))
        end

        repository
      end

      # Core path: the Rust extension parses and emits the model hash
      # directly (lutaml wire shape); Ruby hydrates, then remark
      # attachment runs on the source as usual.
      def self.from_file_core(file, skip_references: nil,
                              include_source: nil, root_path: nil, &block)
        unless Core::NATIVE_AVAILABLE
          raise Error::StreamingUnsupportedError,
                "core parse requires the native extension"
        end

        Expressir::Benchmark.measure_file(file) do
          source = strip_bom(File.read(file))
          schema_file = root_path ? Pathname.new(file.to_s).relative_path_from(root_path).to_s : file.to_s

          exp_file =
            begin
              Core.parse_to_model(source, schema_file).tap(&:wire_parents)
            rescue NotImplementedError
              begin
                Model::ExpFile.from_hash(
                  Core.parse_to_model_hash(source, schema_file),
                )&.tap(&:wire_parents)
              rescue StandardError => e
                raise Error::SchemaParseFailure.new(schema_file, e)
              end
            rescue StandardError => e
              raise Error::SchemaParseFailure.new(schema_file, e)
            end

          finalize_loaded_file(exp_file, source, schema_file,
                               include_source: include_source)

          unless skip_references
            Expressir::Benchmark.measure_references do
              ResolveReferencesModelVisitor.new.visit(exp_file)
            end
          end

          exp_file
        end
      end
      private_class_method :from_file_core

      # Shared post-parse steps for every core-path file: remark
      # attachment, header-remark transfer, and path wiring.
      def self.finalize_loaded_file(exp_file, source, schema_file,
                                    include_source: nil)
        RemarkAttacher.new(source).attach(exp_file) if source && include_source != false

        transfer_header_to_schema(exp_file, source)

        exp_file.path = schema_file
        exp_file.schemas.each do |schema|
          schema.file = schema_file
          schema.file_basename = File.basename(schema_file, ".exp")
        end
      end
      private_class_method :finalize_loaded_file

      # Whether the native batch compiler is usable: the extension is
      # loaded and exposes BatchStream.
      def self.batch_available?
        Core::NATIVE_AVAILABLE &&
          ::Expressir::Core.const_defined?(:BatchStream, false)
      end
      private_class_method :batch_available?

      # Whether the compiled-set artifact APIs are exposed.
      def self.core_set_available?
        Core::NATIVE_AVAILABLE && ::Expressir::Core.const_defined?(:Set, false)
      end

      # Concurrent core-path parse: workers compile in the background
      # while this thread hydrates, attaches remarks, and reports
      # progress per file. Results keep the input order; a file that
      # fails to parse is nil-padded exactly like the other paths.
      def self.from_files_batch(files, include_source: nil, root_path: nil,
                                max_processes: nil, compiled_set_out: nil,
                                &progress)
        schema_file_for = lambda do |file|
          root_path ? Pathname.new(file.to_s).relative_path_from(root_path).to_s : file.to_s
        end
        wire_paths = files.map { |f| schema_file_for.call(f) }
        physical = wire_paths.zip(files.map(&:to_s)).to_h

        results = {}
        jobs = files.map { |f| [f.to_s, schema_file_for.call(f)] }
        # Outcomes arrive in completion order; files are finalized and
        # reported in input order (the contract every other path keeps).
        pending = {}
        stream = ::Expressir::Core::BatchStream.start(jobs, max_processes.to_i)
        cursor = 0
        while (item = stream.next)
          wire_path, model, error = item
          if error
            # Unreadable sources raise like every other path; parse
            # failures nil-pad and report.
            raise Errno::ENOENT, error if error.start_with?("read ")

            pending[wire_path] = [nil, error]
          else
            pending[wire_path] = [model, nil]
          end
          while (entry = pending[wire_paths[cursor]])
            pending.delete(wire_paths[cursor])
            ordered_path = wire_paths[cursor]
            file = physical[ordered_path]
            loaded, load_error = entry
            if loaded
              source = strip_bom(File.read(file))
              loaded.wire_parents
              finalize_loaded_file(loaded, source, ordered_path,
                                   include_source: include_source)
              results[ordered_path] = loaded
              yield(file, loaded, nil)
            else
              results[ordered_path] = nil
              yield(file, nil,
                    Error::SchemaParseFailure.new(ordered_path,
                                                  RuntimeError.new(load_error)))
            end
            cursor += 1
          end
        end

        if compiled_set_out && !results.value?(nil)
          stream.write_set(compiled_set_out, physical,
                           Expressir::Version::VERSION)
          RemarkOverlay.write(compiled_set_out, results.values.compact)
        end

        wire_paths.map { |wire_path| results[wire_path] }
      end
      private_class_method :from_files_batch

      # Warm start from a compiled-set artifact. Returns nil (caller
      # falls back to compiling) when the artifact is unreadable or no
      # longer matches the sources. Remarks are re-attached from the
      # source files and references are resolved as usual — everything
      # not carried by the wire is deterministic and cheap to rebuild.
      def self.from_compiled_set(path, files, skip_references: nil,
                                 include_source: nil, root_path: nil, &progress)
        schema_file_for = lambda do |file|
          root_path ? Pathname.new(file.to_s).relative_path_from(root_path).to_s : file.to_s
        end
        physical = files.to_h { |f| [schema_file_for.call(f), f.to_s] }

        set = begin
          ::Expressir::Core::Set.open(path)
        rescue StandardError
          nil
        end
        return nil if set.nil?
        return nil unless set.matches_sources(physical) == true

        models = []
        while (pair = set.next)
          wire_path, model = pair
          file = physical[wire_path]
          # The artifact wire is pre-remark; the overlay carries them
          # (plus header remarks and remark-derived structures), so the
          # RemarkAttacher never runs on a warm load.
          model.wire_parents
          finalize_loaded_file(model, nil, wire_path,
                               include_source: include_source)
          models << model
          progress&.call(file || wire_path, model.schemas, nil)
        end
        RemarkOverlay.apply(path, models)

        repository = build_repository(models, skip_references: true)
        graph_path = "#{path}.graph.json"
        if File.exist?(graph_path)
          require "json"
          repository.item_graph =
            Model::Indexes::ItemGraph.from_tables(JSON.parse(File.read(graph_path)))
        end
        if skip_references || RefsOverlay.apply_to(path, models)
          # Either explicitly skipping resolution or the compiled-set
          # refs sidecar already re-bound the references.
        else
          Expressir::Benchmark.measure_references do
            ResolveReferencesModelVisitor.new.visit(repository)
          end
        end
        repository
      end
      private_class_method :from_compiled_set

      def self.parse_files_sequentially(files, skip_references: nil,
include_source: nil, root_path: nil, use_native: nil, &block)
        all_exp_files = []

        files.each do |file|
          exp_file = from_file(file, skip_references: true,
                                     root_path: root_path, use_native: use_native)
          all_exp_files << exp_file

          yield(file, exp_file, nil) if block
        rescue StandardError => e
          # Nil-pad so results align with files by index, exactly like the
          # parallel path does.
          all_exp_files << nil if e.is_a?(Error::SchemaParseFailure)
          yield(file, nil, e) if block
          raise unless e.is_a?(Error::SchemaParseFailure)
        end

        all_exp_files
      end

      # Artifact write for the non-batch paths (single file,
      # EXPRESSIR_BATCH=0, small sequential sets): serializes the
      # parsed models through Core.write_set, producing the same
      # artifact shape the batch path writes natively. The wire is
      # pre-remark — RemarkOverlay.write carries the remark-derived
      # attributes, exactly as it does for the batch path.
      def self.write_compiled_set(set_path, files, exp_files, root_path)
        require "digest"
        require "json"
        schema_file_for = lambda do |file|
          root_path ? Pathname.new(file.to_s).relative_path_from(root_path).to_s : file.to_s
        end
        entries = files.zip(exp_files).map do |file, exp_file|
          [schema_file_for.call(file),
           Digest::SHA256.file(file.to_s).hexdigest,
           JSON.generate(strip_remark_wire(exp_file.to_hash))]
        end
        ::Expressir::Core.write_set(set_path, entries, Expressir::Version::VERSION)
        RemarkOverlay.write(set_path, exp_files)
      end
      private_class_method :write_compiled_set

      # Deep copy of a serialized model without the RemarkOverlay
      # attributes: the artifact wire carries only the parsed model;
      # untagged remarks are plain hashes that the Rust hydrator
      # cannot instantiate, and every remark-derived value belongs to
      # the overlay anyway.
      def self.strip_remark_wire(node)
        case node
        when Hash
          node.each_with_object({}) do |(key, value), out|
            out[key] = strip_remark_wire(value) unless RemarkOverlay::CAPTURED.include?(key)
          end
        when Array
          node.map { |value| strip_remark_wire(value) }
        else
          node
        end
      end
      private_class_method :strip_remark_wire

      def self.build_repository(all_exp_files, skip_references: nil)
        repository = Model::Repository.new(files: all_exp_files)

        unless skip_references
          Expressir::Benchmark.measure_references do
            ResolveReferencesModelVisitor.new.visit(repository)
          end
        end

        repository
      end

      # Parses Express content string into an Express model.
      # @param content [String] EXPRESS source code
      # @param skip_references [Boolean] skip resolving references
      # @param include_source [Boolean] attach original source code to model elements
      # @param use_native [Boolean] use native parser (default: true when available)
      # @param use_streaming [Boolean] unsupported on current parsanol;
      #   passing true raises {Error::StreamingUnsupportedError}. The
      #   streaming paths return when parsanol exposes a stable
      #   parse_with_builder (see parsanol-ruby#52 and the TODO.max-perf/02
      #   notes).
      # @return [Model::ExpFile] Parsed ExpFile
      # @raise [Error::SchemaParseFailure] if the content fails to parse
      def self.from_exp(content, skip_references: nil, include_source: nil,
                         use_native: nil, use_streaming: false, dialect: nil)
        Dialect.normalize(dialect)
        content = strip_bom(content)
        if use_streaming
          raise Error::StreamingUnsupportedError
        end

        use_native = Grammar::Parser.native_available? if use_native.nil?

        begin
          ast = if use_native && Grammar::Parser.native_available?
                  Grammar::Parser.parse_native(content)
                else
                  Grammar::Parser.parse_ruby(content)
                end
        rescue Parsanol::ParseFailed, StandardError => e
          raise Error::SchemaParseFailure.new("(from string)", e)
        end

        exp_file = ::Expressir::Express::Builder.build_with_remarks(ast,
                                                                    source: content,
                                                                    include_source: include_source)

        # issue #537 part 2: same gate as from_file — a remark-only
        # fragment is a missing schema, not a grammar dump
        if Array(exp_file&.schemas).empty?
          raise Expressir::SchemaNotFoundError,
                "no schema found in (from string) (remark-only or empty input)"
        end

        transfer_header_to_schema(exp_file, content)

        exp_file.schemas.each do |schema|
          schema.file = nil
          schema.file_basename = nil
        end

        unless skip_references
          Expressir::Benchmark.measure_references do
            ResolveReferencesModelVisitor.new.visit(exp_file)
          end
        end

        exp_file
      end

      # Transfer file-level untagged remarks that appear before the first
      # SCHEMA keyword to the first schema's +header+ attribute so they are
      # accessible via +schema.header+ and through Liquid drops.
      def self.transfer_header_to_schema(exp_file, source = nil)
        return unless exp_file.untagged_remarks&.any?
        return unless exp_file.schemas&.any?
        return unless source

        schema_pos = source.b.index(/\bSCHEMA\b/)
        return unless schema_pos

        header_remarks = exp_file.untagged_remarks.select do |r|
          r.source_offset && r.source_offset < schema_pos
        end
        return unless header_remarks.any?

        header_text = header_remarks.map(&:text).join("\n")
        exp_file.schemas.first.header = header_text
        exp_file.untagged_remarks -= header_remarks
      end
      private_class_method :transfer_header_to_schema
      private_class_method :parse_files_sequentially
      private_class_method :build_repository
    end
  end
end
