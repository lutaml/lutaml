# frozen_string_literal: true

module Lutaml
  module Uml
    # Immutable value object representing a UML package path.
    #
    # A package path consists of one or more segments separated by "::".
    # Examples:
    #   - "ModelRoot"
    #   - "ModelRoot::Conceptual Models"
    #   - "ModelRoot::Conceptual Models::i-UR::urf"
    #
    # PackagePath objects are immutable and frozen after initialization.
    class PackagePath
      SEPARATOR = "::"

      attr_reader :path

      # Create a new PackagePath from a string or array.
      #
      # @param path [String, Array<String>]
      # The package path string or array of segments
      # @raise [ArgumentError] if path is nil
      def initialize(path) # rubocop:disable Metrics/MethodLength
        if path.nil?
          raise ArgumentError, "Path cannot be nil"
        end

        # Handle both string and array inputs
        @segments = if path.is_a?(Array)
                      path.reject { |s| s.nil? || s.empty? }.freeze
                    else
                      # String input - allow empty string
                      # Filter out empty segments from string paths
                      path.split(SEPARATOR).reject(&:empty?).freeze
                    end
        @path = @segments.join(SEPARATOR).freeze

        freeze
      end

      # Get the segments of this path.
      #
      # @return [Array<String>] The path segments
      # @example
      #   PackagePath.new("ModelRoot::i-UR::urf").segments
      #   # => ["ModelRoot", "i-UR", "urf"]
      def segments
        @segments
      end

      # Get the separator used in package paths.
      #
      # @return [String] The separator ("::")
      def separator
        SEPARATOR
      end

      # Check if this is an absolute path (starts with "ModelRoot").
      #
      # @return [Boolean] true if absolute, false otherwise
      def absolute?
        segments.first == "ModelRoot"
      end

      # Get the depth of this path.
      #
      # Depth is counted as number of separators (segments.size - 1).
      #
      # @return [Integer] The depth of the path (0 for single segment)
      # @example
      #   PackagePath.new("ModelRoot").depth # => 0
      #   PackagePath.new("ModelRoot::i-UR").depth # => 1
      #   PackagePath.new("ModelRoot::i-UR::urf").depth # => 2
      def depth
        return 0 if segments.empty?

        segments.size - 1
      end

      # Get the parent path.
      #
      # @return [PackagePath, nil] The parent path, or nil if at root
      # @example
      #   PackagePath.new("ModelRoot::i-UR::urf").parent
      #   # => PackagePath("ModelRoot::i-UR")
      def parent
        return nil if segments.size <= 1

        self.class.new(segments[0...-1])
      end

      # Create a child path by appending a segment.
      #
      # @param name [String] The segment name to append
      # @return [PackagePath] A new PackagePath with the appended segment
      # @example
      #   PackagePath.new("ModelRoot::i-UR").child("urf")
      #   # => PackagePath("ModelRoot::i-UR::urf")
      def child(name)
        self.class.new("#{@path}#{SEPARATOR}#{name}")
      end

      # Get the relative path from a base path.
      #
      # @param base_path_string [String, PackagePath]
      # The base path to calculate relative to
      # @return [PackagePath] The relative path, or self if not relative
      # @example
      #   path = PackagePath.new("ModelRoot::i-UR::urf")
      #   path.relative_to("ModelRoot::i-UR")
      #   # => PackagePath("urf")
      def relative_to(base_path_string)
        base = if base_path_string.is_a?(PackagePath)
                 base_path_string
               else
                 self.class.new(base_path_string)
               end
        return self unless starts_with?(base)

        remaining = segments[base.segments.size..]
        return self.class.new("") if remaining.empty?

        self.class.new(remaining)
      end

      # Check if this path starts with another path.
      #
      # @param other [PackagePath, String] The path to check against
      # @return [Boolean] true if this path starts with other
      # @example
      #   path = PackagePath.new("ModelRoot::i-UR::urf")
      #   path.starts_with?("ModelRoot::i-UR") # => true
      #   path.starts_with?("ModelRoot::CityGML") # => false
      def starts_with?(other)
        other_path = other.is_a?(PackagePath) ? other : self.class.new(other)
        return false if other_path.segments.size > segments.size

        segments[0...other_path.segments.size] == other_path.segments
      end

      # Check if this path matches a glob pattern.
      #
      # Supports:
      #   - "*" to match a single segment
      #   - "**" to match zero or more segments
      #
      # @param pattern [String] The glob pattern
      # @return [Boolean] true if the path matches the pattern
      # @example
      #   path = PackagePath.new("ModelRoot::i-UR::urf")
      #   path.matches_glob?("ModelRoot::*::urf") # => true
      #   path.matches_glob?("ModelRoot::**") # => true
      #   path.matches_glob?("ModelRoot::*") # => false
      def matches_glob?(pattern)
        pattern_segments = pattern.split(SEPARATOR)
        match_segments(segments, pattern_segments)
      end

      # Check if this path is empty.
      #
      # @return [Boolean] true if empty (no segments)
      def empty?
        @segments.empty?
      end

      # Convert to string representation.
      #
      # @return [String] The path as a string
      def to_s
        @path
      end

      # Check equality with another PackagePath.
      #
      # @param other [Object] The object to compare with
      # @return [Boolean] true if equal
      def ==(other)
        other.is_a?(PackagePath) && @path == other.path
      end

      alias eql? ==

      # Generate hash code for this path.
      #
      # @return [Integer] The hash code
      def hash
        @path.hash
      end

      private

      # Recursively match path segments against pattern segments.
      #
      # @param path_segs [Array<String>] Remaining path segments
      # @param pattern_segs [Array<String>] Remaining pattern segments
      # @return [Boolean] true if segments match pattern
      def match_segments(path_segs, pattern_segs) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        return path_segs.empty? if pattern_segs.empty?
        return false if path_segs.empty? && !pattern_segs.all? { |s| s == "**" }

        pattern_seg = pattern_segs.first

        case pattern_seg
        when "**"
          # Match zero or more segments
          return true if pattern_segs.size == 1

          # Try matching with 0, 1, 2, ... segments consumed
          (0..path_segs.size).any? do |i|
            match_segments(path_segs[i..], pattern_segs[1..])
          end
        when "*"
          # Match exactly one segment
          return false if path_segs.empty?

          match_segments(path_segs[1..], pattern_segs[1..])
        else
          # Match segment - support string wildcards like "Class*"
          return false if path_segs.empty?

          if pattern_seg.include?("*")
            # Convert glob pattern to regex
            regex_pattern = Regexp.escape(pattern_seg).gsub('\*', ".*")
            return false unless path_segs.first.match?(/\A#{regex_pattern}\z/)
          else
            return false unless path_segs.first == pattern_seg
          end

          match_segments(path_segs[1..], pattern_segs[1..])
        end
      end
    end
  end
end
