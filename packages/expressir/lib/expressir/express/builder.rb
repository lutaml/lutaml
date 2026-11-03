# frozen_string_literal: true

module Expressir
  module Express
    # Builder registry for AST node type handlers.
    # Each builder is a callable object that transforms AST data into Model objects.
    # This is the ONLY way to build models from AST - no Transformer fallback.
    module Builder
      class << self
        # Thread-local key under which the current BuilderContext is stored
        # for the duration of a build_with_remarks call. Recursive build
        # calls read source/include_source from here instead of from
        # class-level mutable state.
        CONTEXT_KEY = :expressir_builder_context

        # Returns the BuilderContext for the current thread, or nil if no
        # build is in progress.
        def current_context
          Thread.current[CONTEXT_KEY]
        end

        # Convenience accessors — read from the current context.
        def source
          current_context&.source
        end

        def include_source
          current_context&.include_source
        end

        # Register a builder for a node type.
        # @param node_type [Symbol] The AST node type
        # @param builder [#call] Optional callable that takes (ast_data)
        # @yield Block that takes (ast_data) if builder not provided
        def register(node_type, builder = nil, &block)
          @register ||= {}
          @register[node_type] = builder || block
        end

        # Build a Model object from AST data.
        # @param ast [Hash] The AST with node type as key
        # @return [Model::ModelElement] The built model object
        def build(ast)
          return nil unless ast

          # Optimized: Hash is 90%+ of cases, check it first
          case ast
          when Hash
            node_type = ast.keys.first
            node_data = ast[node_type]

            handler_key = AstKeyConverter.snake_case(node_type)
            snake_data = AstKeyConverter.convert(node_data)

            builder = @register[handler_key]
            if builder
              result = builder.call(snake_data)

              # Fast path: single-key hash or non-nil result
              if !result.nil? || ast.keys.length <= 1
                attach_source_info(result, node_data)
                return result
              end

              # Slow path: first-key builder returned nil in a multi-key
              # hash. Try remaining keys for actual content. This handles
              # grammar patterns like `element >> (op_comma >> element).repeat`
              # which produce {:op_comma => ..., :element => {...}} where
              # the first key is an operator separator.
              # Previously gated by a hand-maintained OPERATOR_TOKENS set;
              # now tries all remaining keys unconditionally (TODO.bugs/21).
              ast.each_key do |key|
                next if key == node_type

                h_key = AstKeyConverter.snake_case(key)
                h_builder = @register[h_key]
                next unless h_builder

                n_data = ast[key]
                s_data = AstKeyConverter.convert(n_data)
                result = h_builder.call(s_data)

                unless result.nil?
                  attach_source_info(result, n_data)
                  return result
                end
              end
            else
              raise Error::UnknownNodeTypeError, node_type
            end
            nil
          when Array
            ast.map do |item|
              build(item)
            end
          when Parsanol::Slice
            ast.to_s
          else
            ast
          end
        end

        # Build with remark attachment.
        #
        # Sets up a BuilderContext as a thread-local for the duration of the
        # build so recursive build calls can read source/include_source via
        # `Builder.source` / `Builder.include_source`. The previous context
        # (if any) is restored on exit so nested builds are reentrant.
        def build_with_remarks(ast, source: nil, include_source: nil)
          # Trigger BuilderRegistry autoload so all AST node type handlers
          # are registered before build() runs. The reference to
          # BuilderRegistry resolves the autoload defined in express.rb.
          BuilderRegistry

          previous = Thread.current[CONTEXT_KEY]
          Thread.current[CONTEXT_KEY] = BuilderContext.new(
            source: source,
            include_source: include_source,
          )

          result = build(ast)

          # Only attach remarks if include_source is explicitly true
          # (nil means use default behavior - attach remarks)
          if source && result && include_source != false
            attacher = RemarkAttacher.new(source)
            attacher.attach(result)
          end

          result
        ensure
          Thread.current[CONTEXT_KEY] = previous
        end

        # Check if a builder is registered for a node type.
        def registered?(node_type)
          @register&.key?(node_type)
        end

        # Get all registered node types.
        def registered_types
          @register&.keys || []
        end

        # Build optional (returns nil if ast is nil)
        def build_optional(ast)
          return nil unless ast

          build(ast)
        end

        # Normalize a value to an Array for iteration.
        # Handles: nil → [], Parsanol::Slice → [], Array → Array, other → [other]
        def ensure_array(value)
          return [] if value.nil?
          return [] if value.is_a?(Parsanol::Slice)

          value.is_a?(Array) ? value : [value]
        end

        # Build children (array of AST nodes)
        # Optimized to avoid intermediate array allocations
        def build_children(ast_array)
          return [] if ast_array.nil?

          # Handle Parsanol::Slice (empty Slices from optional rules)
          # Convert to empty Array
          if ast_array.is_a?(Parsanol::Slice)
            return []
          end

          # Handle single element (common case)
          unless ast_array.is_a?(Array)
            return [build(ast_array)].compact
          end

          # Build result in single pass, avoiding flatten/compact/map chain
          result = []
          ast_array.each do |item|
            next if item.nil?

            # Empty Slices from optional rules should be treated as empty arrays
            if item.is_a?(Parsanol::Slice)
              next
            end

            case item
            when Array
              item.each { |sub| append_built(result, build(sub)) unless sub.nil? }
            else
              append_built(result, build(item))
            end
          end
          result
        end

        # Builders for list productions (ExplicitAttrBuilder and friends)
        # return Arrays of nodes. Splice those items into the parent list
        # rather than nesting them — nested Arrays break every consumer
        # that expects ModelElements (`x.kind`, tree walks, formatters).
        def append_built(result, built)
          case built
          when nil
            nil
          when Array
            built.each { |b| append_built(result, b) }
          else
            result << built
          end
        end

        # Fast build methods - call registered builder directly without hash wrapping
        # These are optimized for hot paths in expression building
        # NOTE: These assume data is already snake_case (no key conversion needed)

        # Call a registered builder directly with data (avoids hash wrapper allocation)
        # @param node_type [Symbol] The node type key
        # @param data The data to pass to the builder (already snake_case)
        def build_node(node_type, data)
          builder = @register&.[](node_type)
          raise Error::UnknownNodeTypeError, node_type unless builder

          builder.call(data)
        end

        # Keys containing uppercase need snake-casing; testing the key
        # directly avoids allocating `to_s` strings per key per pass.
        # Key conversion lives in AstKeyConverter (MECE: converting AST
        # keys is not building models).
        def extract_source_info(data)
          return nil unless data

          src = source
          return nil unless src

          slice = find_slice(data)
          return nil unless slice

          {
            text: src[slice.offset...(slice.offset + slice.length)]&.strip,
            offset: slice.offset,
          }
        end

        def attach_source_info(result, data)
          return unless source && result.is_a?(Expressir::Model::ModelElement)

          source_info = extract_source_info(data)
          return unless source_info

          result.source_offset = source_info[:offset]
          result.source = source_info[:text] if include_source
        end

        def find_slice(data, depth = 0)
          return nil if depth > 10

          case data
          when Parsanol::Slice
            data
          when Hash
            # Skip 'spaces' key which contains whitespace/comments before content
            # Look for 'str' key first as it usually contains the actual content
            if data.key?(:str) && data[:str].is_a?(Parsanol::Slice)
              return data[:str]
            end

            # Then look in other keys, skipping 'spaces'
            data.each do |key, value|
              next if key == :spaces

              return value if value.is_a?(Parsanol::Slice)

              result = find_slice(value, depth + 1)
              return result if result
            end
            nil
          when Array
            data.each do |item|
              result = find_slice(item, depth + 1)
              return result if result
            end
            nil
          end
        end
      end
    end
  end
end
