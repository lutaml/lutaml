# frozen_string_literal: true

module Expressir
  module Express
    # Streaming builder that receives parse events from Parsanol native parser.
    #
    # This builder implements the Parsanol::BuilderCallbacks interface and
    # reconstructs the AST from streaming events, then uses the existing
    # Builder to convert to Model objects.
    #
    # The key insight is that when a value starts (HASH_START, ARRAY_START),
    # we must FIRST add it to the parent with the pending key, THEN push it
    # to the stack so nested values are added to the correct container.
    #
    class StreamingBuilder
      # Include Parsanol callbacks if available
      if defined?(Parsanol::BuilderCallbacks)
        include Parsanol::BuilderCallbacks
      end

      # @return [String, nil] Original source code for position tracking
      attr_accessor :source

      # @return [Boolean] Whether to include source in model elements
      attr_reader :include_source

      # Initialize the streaming builder
      #
      # @param source [String, nil] Original source code
      # @param include_source [Boolean] Whether to include source in model elements
      def initialize(source: nil, include_source: nil)
        @source = source
        @include_source = include_source
        @stack = [] # Stack of containers (Hash or Array)
        @pending_key = nil
        @final_ast = nil
      end

      # Called when parsing starts
      #
      # @param input [String] The input being parsed
      def on_start(input)
        @on_start ||= input
      end

      # Called when parsing succeeds
      def on_success
        # Parsing completed
      end

      # Called when parsing fails
      #
      # @param message [String] The error message
      def on_error(message)
        raise Error::SchemaParseFailure.new("(streaming)", message)
      end

      # Called when a string value is matched
      #
      # @param value [String] The matched string value
      # @param offset [Integer] Byte offset
      # @param length [Integer] Length
      def on_string(value, _offset, _length)
        add_value_to_current_container(value)
      end

      # Called when an integer value is matched
      #
      # @param value [Integer] The matched integer value
      def on_int(value)
        add_value_to_current_container(value)
      end

      # Called when a float value is matched
      #
      # @param value [Float] The matched float value
      def on_float(value)
        add_value_to_current_container(value)
      end

      # Called when a boolean value is matched
      #
      # @param value [Boolean] The matched boolean value
      def on_bool(value)
        add_value_to_current_container(value)
      end

      # Called when a nil/null value is matched
      def on_nil
        add_value_to_current_container(nil)
      end

      # Called when starting to parse a hash/object
      #
      # @param size [Integer, nil] Expected number of entries
      def on_hash_start(_size = nil)
        new_hash = {}

        # First add this hash to the parent (if any) with the pending key
        if @stack.any?
          add_value_to_current_container(new_hash)
        end

        # Then push to stack so nested values go into this hash
        @stack.push(new_hash)
        # Clear pending key - we're starting a new hash context
        @pending_key = nil
      end

      # Called when a hash key is encountered
      #
      # @param key [String] The hash key name
      def on_hash_key(key)
        # Convert string key to symbol to match existing parser AST format
        @pending_key = key.to_sym
      end

      # Called when a hash value is about to be parsed
      #
      # @param key [String] The hash key name
      def on_hash_value(_key)
        @pending_key = nil
      end

      # Called when finishing parsing a hash/object
      #
      # @param size [Integer] Actual number of entries
      def on_hash_end(_size)
        return if @stack.empty?

        finished_hash = @stack.pop

        if @stack.empty?
          # This is the top-level hash, save it as final AST
          @final_ast = finished_hash
        end
        # If there's a parent, the hash was already added in on_hash_start
      end

      # Called when starting to parse an array
      #
      # @param size [Integer, nil] Expected number of elements
      def on_array_start(_size = nil)
        new_array = []

        # First add this array to the parent (if any) with the pending key
        if @stack.any?
          add_value_to_current_container(new_array)
        end

        # Then push to stack
        @stack.push(new_array)
        # Clear pending key - we're starting a new array context
        @pending_key = nil
      end

      # Called when an array element is about to be parsed
      #
      # @param index [Integer] The index of the element
      def on_array_element(index)
        # Element processed - no action needed
      end

      # Called when finishing parsing an array
      #
      # @param size [Integer] Actual number of elements
      def on_array_end(_size)
        return if @stack.empty?

        finished_array = @stack.pop

        if @stack.empty?
          # Top-level array, save as final AST
          @final_ast = finished_array
        end
        # If there's a parent, the array was already added in on_array_start
      end

      # Called when starting to parse a named rule
      #
      # @param name [String] The rule name
      def on_named_start(name)
        # Named captures are handled via hash wrapping - no action needed
      end

      # Called when finishing parsing a named rule
      #
      # @param name [String] The rule name
      def on_named_end(name)
        # Named captures are handled via hash wrapping - no action needed
      end

      # Called when parsing is complete. Returns the built Repository.
      #
      # @return [Model::Repository, nil] The final result
      def finish
        return nil unless @final_ast

        # Convert Parsanol native AST format to Builder-compatible format
        # Parsanol native: {"key" => [{:a => ...}, {:b => ...}]}  (Array of single-key hashes)
        # Builder:  {:key => {:a => ..., :b => ...}}       (Hash with multiple keys)
        converted_ast = convert_ast_format(@final_ast)

        # Pass to the existing Builder
        Builder.build_with_remarks(converted_ast, source: @source,
                                                  include_source: @include_source)
      end

      private

      # Process a hash, concatenating :str and :spaces arrays
      # This is called after merging single-key hashes
      def process_str_and_spaces(hash)
        result = {}
        hash.each do |key, value|
          result[key] = if %i[str spaces].include?(key) && value.is_a?(Array)
                          value.compact.join
                        else
                          value
                        end
        end
        result
      end

      # Convert Parsanol native AST format to Builder-compatible format
      #
      # Parsanol native represents:
      # - Sequences as arrays of single-key hashes: [{:a => 1}, {:b => 2}, []]
      # - Strings as arrays of characters: {:str => ["a", "b", "c", nil]}
      # - Spaces as arrays of whitespace: {:spaces => [" ", "\\n"]}
      #
      # Builder expects:
      # - Sequences as hashes with multiple keys: {:a => 1, :b => 2}
      # - Strings as concatenated strings: {:str => "abc"}
      # - Spaces as concatenated strings: {:spaces => " "}
      #
      # @param obj [Object] The AST node to convert
      # @return [Object] The converted AST
      def convert_ast_format(obj)
        case obj
        when Hash
          convert_hash_node(obj)
        when Array
          convert_array_node(obj)
        else
          obj
        end
      end

      def convert_hash_node(hash)
        return hash if hash.empty?

        result = {}
        hash.each do |key, value|
          result[key] = if %i[str spaces].include?(key) && value.is_a?(Array)
                          value.compact.join
                        else
                          convert_ast_format(value)
                        end
        end
        result
      end

      def convert_array_node(array)
        return array if array.empty?

        converted_items = array.map { |item| convert_ast_format(item) }

        # Flatten nested arrays from grammar repetition (.repeat)
        flattened = flatten_nested_arrays(converted_items)

        non_empty = flattened.reject { |item| item.nil? || (item.is_a?(Array) && item.empty?) }

        if non_empty.empty?
          {}
        elsif non_empty.all?(Hash)
          merge_or_preserve_sequence(non_empty, flattened)
        else
          flattened
        end
      end

      def flatten_nested_arrays(items)
        result = []
        items.each do |item|
          if item.is_a?(Array)
            result.concat(item)
          else
            result << item
          end
        end
        result
      end

      def merge_or_preserve_sequence(non_empty, converted)
        # Check for repetition patterns that should stay as arrays
        return converted if same_key_repetition?(non_empty)
        return converted if duplicate_key_repetition?(non_empty)

        # Check for grouped repetition that needs unzipping
        unzipped = try_unzip_repetition(non_empty)
        return unzipped if unzipped

        # Default: merge all single-key hashes into one hash
        merge_sequence_hashes(non_empty)
      end

      def same_key_repetition?(items)
        first_keys = items.first.keys
        first_keys.length == 1 &&
          items.length > 1 &&
          items.all? { |item| item.keys.length == 1 && item.keys.first == first_keys.first }
      end

      def duplicate_key_repetition?(items)
        all_keys = items.flat_map(&:keys)
        key_counts = all_keys.tally
        key_counts.any? { |_, count| count > 1 }
      end

      def try_unzip_repetition(items)
        return nil unless items.length >= 2

        first_item = items[0]
        later_items = items[1..]
        return nil unless first_item.keys.length == 1 && !first_item.values.first.is_a?(Array)

        first_key = first_item.keys.first
        repetition_item = later_items.find do |item|
          item.key?(first_key) &&
            item[first_key].is_a?(Array) &&
            item[first_key].length > 1 &&
            item.keys.length >= 2
        end
        return nil unless repetition_item

        unzip_grouped_repetition(first_item, later_items)
      end

      def unzip_grouped_repetition(first_item, later_items)
        result = [first_item]

        later_items.each do |item|
          array_keys = item.select { |_, v| v.is_a?(Array) && v.length > 1 }.keys

          if array_keys.empty?
            result << item
          elsif array_keys.length == 1
            expand_single_array_key(item, array_keys.first, result)
          else
            expand_multiple_array_keys(item, array_keys, result)
          end
        end

        result
      end

      def expand_single_array_key(item, key, result)
        values = item[key]
        other_keys = item.keys - [key]

        values.each do |val|
          new_item = { key => val }
          other_keys.each { |ok| new_item[ok] = item[ok] }
          result << new_item
        end
      end

      def expand_multiple_array_keys(item, array_keys, result)
        len = array_keys.map { |k| item[k].length }.max
        other_keys = item.keys - array_keys

        len.times do |idx|
          new_item = {}
          array_keys.each do |k|
            values = item[k]
            new_item[k] = values[idx] if idx < values.length
          end
          other_keys.each { |ok| new_item[ok] = item[ok] }
          result << new_item
        end
      end

      def merge_sequence_hashes(items)
        merged = {}
        items.each do |item|
          item.each do |key, value|
            if merged.key?(key)
              existing = merged[key]
              if existing.is_a?(Array)
                existing.is_a?(Array) && value.is_a?(Array) ? existing.concat(value) : existing << value
              else
                merged[key] = [existing, value]
              end
            else
              merged[key] = value
            end
          end
        end
        process_str_and_spaces(merged)
      end

      # Add a value to the current container on top of the stack
      #
      # @param value The value to add
      def add_value_to_current_container(value)
        return if @stack.empty?

        container = @stack.last

        if container.is_a?(Hash)
          if @pending_key
            container[@pending_key] = value
          end
        elsif container.is_a?(Array)
          container << value
        else
          # This handles unexpected container types (debugging)
          if ENV["DEBUG_STREAMING"]
            puts "  Container value: #{container.inspect[0..200]}"
            puts "  Pending key: #{@pending_key.inspect}"
            puts "  Stack depth: #{@stack.length}"
            puts "  Stack: #{@stack.map(&:class).inspect}"
          end
          raise "Unexpected container type: #{container.class}"
        end
      end

      # Get the final AST (for debugging)
      def final_ast
        @final_ast
      end
    end
  end
end
