# frozen_string_literal: true

require_relative "package_path"

module Lutaml
  module Uml
    # Immutable value object representing a UML qualified class name.
    #
    # A qualified name consists of a package path and a class name.
    # Examples:
    #   - "i-UR::urf::UrbanPlanningArea"
    #     (package: "i-UR::urf", class: "UrbanPlanningArea")
    #   - "ModelRoot::CityGML::Building"
    #     (package: "ModelRoot::CityGML", class: "Building")
    #
    # QualifiedName objects are immutable and frozen after initialization.
    class QualifiedName
      attr_reader :package_path, :class_name

      # Create a new QualifiedName.
      #
      # @param qualified_name_string [String] The full qualified name
      #   (e.g., "i-UR::urf::UrbanPlanningArea")
      # @raise [ArgumentError] if qualified_name_string is invalid
      def initialize(qualified_name_string)
        if qualified_name_string.nil? || qualified_name_string.empty?
          raise ArgumentError, "Qualified name cannot be nil or empty"
        end

        parts = qualified_name_string.split(PackagePath::SEPARATOR)
        if parts.size < 2
          raise ArgumentError,
                "Qualified name must contain at least package and class name"
        end

        @class_name = parts.last.freeze
        @package_path = PackagePath.new(parts[0...-1].join(PackagePath::SEPARATOR))
        freeze
      end

      # Convert to string representation.
      #
      # @return [String] The fully qualified name
      # @example
      #   qname = QualifiedName.new("i-UR::urf::UrbanPlanningArea")
      #   qname.to_s # => "i-UR::urf::UrbanPlanningArea"
      def to_s
        "#{@package_path}#{PackagePath::SEPARATOR}#{@class_name}"
      end

      # Check if this class is in the specified package.
      #
      # @param path [String, PackagePath] The package path to check
      # @return [Boolean] true if the class is in the package
      # @example
      #   qname = QualifiedName.new("i-UR::urf::UrbanPlanningArea")
      #   qname.in_package?("i-UR::urf") # => true
      #   qname.in_package?("i-UR") # => false
      def in_package?(path)
        check_path = path.is_a?(PackagePath) ? path : PackagePath.new(path)
        @package_path == check_path
      end

      # Get the relative qualified name from a base package path.
      #
      # @param base_path_string [String] The base package path
      # @return [QualifiedName, nil] The relative qualified name, or nil if
      #   not relative
      # @example
      #   qname = QualifiedName.new("ModelRoot::i-UR::urf::UrbanPlanningArea")
      #   qname.relative_to("ModelRoot::i-UR")
      #   # => QualifiedName("urf::UrbanPlanningArea")
      def relative_to(base_path_string)
        relative_path = @package_path.relative_to(base_path_string)
        return nil if relative_path.nil?

        self.class.new("#{relative_path}#{PackagePath::SEPARATOR}#{@class_name}")
      end

      # Check equality with another QualifiedName.
      #
      # @param other [Object] The object to compare with
      # @return [Boolean] true if equal
      def ==(other)
        other.is_a?(QualifiedName) &&
          @package_path == other.package_path &&
          @class_name == other.class_name
      end

      alias eql? ==

      # Generate hash code for this qualified name.
      #
      # @return [Integer] The hash code
      def hash
        [@package_path, @class_name].hash
      end
    end
  end
end
