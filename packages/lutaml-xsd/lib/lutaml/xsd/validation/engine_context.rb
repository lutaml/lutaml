# frozen_string_literal: true

require "moxml"

module Lutaml
  module Xsd
    module Validation
      # EngineContext adapts Moxml::XSD (engine-native XSD validation on
      # leptris/nokogiri) to lutaml-xsd's validation stack.
      #
      # Engine findings are additive: tier-1 engine scope validates laxly
      # outside named+typed top-level elements / one-level content-model
      # descent / lexical checks, so the Ruby rule engine stays
      # authoritative. All query methods return nil (not false) when the
      # engine cannot answer, and callers fall back to Ruby logic.
      #
      # An instance document is validated against the compiled set (root
      # name matched across every member document's top-level elements —
      # the root may live in an imported document) and, when pathless
      # roundtrip schemas exist, against those individually.
      # Repositories (and the global processed-schema cache) hold many
      # unrelated schemas, and blanket validation would let every schema
      # reject every document.
      class EngineContext
        ENGINE_CODE = "engine_validation"

        XSD_NAMESPACE = "http://www.w3.org/2001/XMLSchema"

        CompiledSchema = Struct.new(:handle, :target_namespace, :element_names)

        attr_reader :context, :schemas

        class << self
          # Compile repository schemas for the current adapter.
          #
          # File-backed schemas compile as ONE schema set (Context#xsd_set)
          # so imports resolve across documents — the per-file faces
          # structurally cannot see import-declared nodes (moxml#483).
          # Pathless schemas (minimal spec repositories) keep per-schema
          # roundtrip compiles; the whole set falls back to per-file
          # compiles when the adapter lacks set compilation.
          #
          # @param repository [#all_schemas] Schema repository
          # @param context [Moxml::Context] Adapter context
          # @return [EngineContext, nil] nil when the adapter has no engine
          def compile(repository, context: Moxml::Context.new)
            return nil unless xsd_supported?(context)

            entries = repository.all_schemas.values.filter_map do |schema|
              # The engine's compiled automaton grows with the product
              # of maxOccurs along particle paths; past the guard cap
              # the compile has killed the process (particlesZ034_b) —
              # such schemas stay Ruby-decided.
              next nil unless schema_safe_for_engine?(schema)

              # Minimal repositories carry no source paths (spec'd
              # shape) — the roundtrip compile covers them.
              path = begin
                repository.source_path_for(schema)
              rescue NoMethodError
                nil
              end
              [schema, (path if path && File.exist?(path))]
            end

            new(context, compile_entries(context, entries))
          end

          # @return [Array<CompiledSchema>]
          def compile_entries(context, entries)
            file_entries = entries.select { |_, path| path }
            per_file = file_entries.filter_map do |schema, path|
              compile_schema(context, schema, path)
            end
            pathless = entries.reject { |_, path| path }
              .filter_map { |schema, _| compile_schema(context, schema) }

            # Escalate to a schema set only when EVERY file-backed
            # document compiled cleanly per-file. A failed native compile
            # poisons the engine's state — repeated failures abort later
            # validations — and a broken document would fail the set
            # anyway, so broken schemas stay exactly as inert as the
            # per-file path makes them. Healthy multi-document sets gain
            # the cross-import visibility the per-file faces cannot have.
            compiled_set = nil
            if per_file.size == file_entries.size && file_entries.size > 1
              compiled_set = compile_set(
                context, file_entries.map { |_, path| path }
              )
              if compiled_set
                per_file.each do |compiled|
                  handle = compiled.handle
                  handle.release if handle.is_a?(Moxml::XSD::Schema)
                end
              end
            end

            return [compiled_set] + pathless if compiled_set

            per_file + pathless
          end

          # @return [CompiledSchema, nil] nil on a schema-level set
          #   failure; raises through when the adapter cannot compile
          #   sets at all (nokogiri pins the contract unsupported; older
          #   moxml lacks the face)
          def compile_set(context, paths)
            return nil if paths.empty?

            compiled = context.xsd_set(*paths)
            if compiled.compile_error
              # A rejected compile still owns native state — dropping
              # the handle unreleased accumulates engine pools across
              # batched suite runs.
              compiled.release if compiled.is_a?(Moxml::XSD::Schema)
              return nil
            end

            CompiledSchema.new(
              compiled, nil, set_element_names(context, paths)
            )
          rescue Moxml::NotImplementedError, NoMethodError
            raise
          rescue StandardError
            nil
          end

          def set_element_names(context, paths)
            paths.flat_map do |path|
              inspect_schema(context, File.read(path))[:element_names]
            rescue StandardError
              []
            end
          end

          # An unassessable schema (not a Schema object, malformed model)
          # keeps the engine inert for it — never a warning.
          def schema_safe_for_engine?(schema)
            OccurrenceProductGuard.for_schema(schema).schema_safe?(schema)
          rescue StandardError
            false
          end

          # Whether the adapter ships an XSD validator.
          #
          # @param context [Moxml::Context] Adapter context
          # @return [Boolean]
          def xsd_supported?(context)
            Moxml::XSD.supported?(context)
          rescue Moxml::NotImplementedError, NameError
            false
          end

          # Map a Moxml::XSD::ValidationError into the lutaml-xsd error type
          #
          # @param finding [Moxml::XSD::ValidationError]
          # @return [Validation::ValidationError]
          def map_finding(finding)
            ValidationError.new(
              code: ENGINE_CODE,
              message: finding.message,
              severity: :error,
              location: finding.path,
              line_number: finding.line,
              context: { column: finding.column }.compact,
            )
          end

          private

          def compile_schema(context, schema, path = nil)
            source = schema.to_xml
            # Compiling from the source file lets the engine resolve the
            # schema's relative imports (addD004); the roundtrip loses
            # the location context. Files may be transient — fall back
            # to the roundtrip when the path is gone.
            compiled =
              if path && File.exist?(path)
                context.xsd_file(path)
              else
                context.xsd(source)
              end
            if compiled.compile_error
              compiled.release if compiled.is_a?(Moxml::XSD::Schema)
              return nil
            end

            info = inspect_schema(context, source)
            CompiledSchema.new(
              compiled, info[:target_namespace], info[:element_names]
            )
          rescue StandardError
            nil
          end

          def inspect_schema(context, source)
            doc = context.parse(source)
            root = doc.root
            names = doc.xpath("/xs:schema/xs:element[@name]",
                              "xs" => XSD_NAMESPACE).map { |node| node["name"] }
            { target_namespace: root&.[]("targetNamespace"),
              element_names: names }
          rescue StandardError
            { target_namespace: nil, element_names: [] }
          end
        end

        def initialize(context, schemas)
          @context = context
          @schemas = schemas
        end

        # @return [Boolean] true when at least one schema compiled
        def supported?
          !@schemas.empty?
        end

        # Free the engine-side schema handles. Document pools otherwise
        # accumulate across batched suite runs (moxml#350). Builtin
        # lexical checks are adapter-level and stay usable afterwards.
        #
        # @return [void]
        def release
          @schemas.each do |compiled|
            handle = compiled.handle
            handle.release if handle.is_a?(Moxml::XSD::Schema)
          end
        end

        # Validate raw XML against the compiled schemas that declare the
        # document's root element.
        #
        # @param xml_content [String]
        # @return [Array<Validation::ValidationError>]
        def findings_for(xml_content)
          root = instance_root(xml_content)
          return [] unless root

          matching_schemas(root).flat_map do |compiled|
            compiled.handle.validate(xml_content)
          end.map { |finding| self.class.map_finding(finding) }
        end

        # Lexical check against the built-in type table ("xs:NAME" spelling).
        # A nil from moxml's facade table (moxml#485: date lambdas leak
        # nil instead of false when the lexical misses their regex)
        # normalizes through our own value space — an unknown to them is
        # still decidable here.
        #
        # @param builtin_name [String] e.g. "xs:date"
        # @param lexical [String] the value to check
        # @return [Boolean, nil] nil when neither table can answer
        def builtin_valid?(builtin_name, lexical)
          answer = Moxml::XSD.builtin_valid?(@context, builtin_name, lexical)
          return answer unless answer.nil?

          ValueSpace.lexical_answer(builtin_name, lexical)
        rescue StandardError
          ValueSpace.lexical_answer(builtin_name, lexical)
        end

        # Lexical check against a schema's named simpleType.
        #
        # @param type_name [String]
        # @param lexical [String]
        # @return [Boolean, nil] nil when no compiled schema knows the type
        def simple_valid(type_name, lexical)
          @schemas.each do |compiled|
            answer = compiled.handle.simple_valid?(type_name, lexical)
            return answer
          rescue StandardError
            next
          end
          nil
        end

        # Content-model check for one element's children (Moxml nodes).
        #
        # @param element_name [String]
        # @param children [Array<Moxml::Node>]
        # @return [Boolean, nil] nil when the engine cannot answer
        def content_valid(element_name, children)
          @schemas.each do |compiled|
            answer = compiled.handle.content_valid?(element_name, children)
            return answer
          rescue StandardError
            next
          end
          nil
        end

        private

        def instance_root(xml_content)
          @context.parse(xml_content).root
        rescue StandardError
          nil
        end

        def matching_schemas(root)
          name = root.name
          ns = root_namespace(root)

          @schemas.select do |compiled|
            compiled.element_names.include?(name) &&
              (compiled.target_namespace.nil? ||
               compiled.target_namespace == ns)
          end
        end

        def root_namespace(root)
          root.namespace&.uri
        rescue StandardError
          nil
        end
      end
    end
  end
end
