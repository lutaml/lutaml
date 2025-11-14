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

      # Create a new PackagePath from a string.
      #
      # @param path [String] The package path string (e.g., "ModelRoot::i-UR::urf")
      # @raise [ArgumentError] if path is nil or empty
      def initialize(path)
        raise ArgumentError, "Path cannot be nil or empty" if path.nil? || path.empty?

        @path = path.freeze
        @segments = @path.split(SEPARATOR).freeze
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
      # @return [Integer] The number of segments in the path
      # @example
      #   PackagePath.new("ModelRoot").depth # => 1
      #   PackagePath.new("ModelRoot::i-UR::urf").depth # => 3
      def depth
        segments.size
      end

      # Get the parent path.
      #
      # @return [PackagePath, nil] The parent path, or nil if at root
      # @example
      #   PackagePath.new("ModelRoot::i-UR::urf").parent
      #   # => PackagePath("ModelRoot::i-UR")
      def parent
        return nil if depth <= 1

        self.class.new(segments[0...-1].join(SEPARATOR))
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
      # @param base_path_string [String] The base path to calculate relative to
      # @return [PackagePath, nil] The relative path, or nil if not relative
      # @example
      #   path = PackagePath.new("ModelRoot::i-UR::urf")
      #   path.relative_to("ModelRoot::i-UR")
      #   # => PackagePath("urf")
      def relative_to(base_path_string)
        base = self.class.new(base_path_string)
        return nil unless starts_with?(base)

        remaining = segments[base.depth..]
        return nil if remaining.empty?

        self.class.new(remaining.join(SEPARATOR))
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
        return false if other_path.depth > depth

        segments[0...other_path.depth] == other_path.segments
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
      def match_segments(path_segs, pattern_segs)
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
          # Match exact segment
          return false if path_segs.empty? || path_segs.first != pattern_seg

          match_segments(path_segs[1..], pattern_segs[1..])
        end
      end
    end
  end
end