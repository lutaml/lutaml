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
      # @param qualified_name [String, Array<String>] The full qualified name or array of segments
      #   (e.g., "i-UR::urf::UrbanPlanningArea" or ["i-UR", "urf", "UrbanPlanningArea"])
      # @raise [ArgumentError] if qualified_name is nil
      def initialize(qualified_name)
        if qualified_name.nil?
          raise ArgumentError, "Qualified name cannot be nil"
        end

        # Handle both string and array inputs
        parts = if qualified_name.is_a?(Array)
                  qualified_name.reject { |s| s.nil? || s.empty? }
                else
                  qualified_name.split(PackagePath::SEPARATOR).reject(&:empty?)
                end

        # Allow empty qualified names
        if parts.empty?
          @class_name = "".freeze
          @package_path = PackagePath.new("")
        else
          @class_name = parts.last.freeze
          
          # Package path can be empty for unqualified names
          if parts.size > 1
            @package_path = PackagePath.new(parts[0...-1])
          else
            # Create empty package path
            @package_path = PackagePath.new("")
          end
        end
        
        freeze
      end

      # Convert to string representation.
      #
      # @return [String] The fully qualified name (empty string for empty name)
      # @example
      #   qname = QualifiedName.new("i-UR::urf::UrbanPlanningArea")
      #   qname.to_s # => "i-UR::urf::UrbanPlanningArea"
      def to_s
        return "" if @class_name.nil? || @class_name.empty?
        
        # Check if package path is empty
        if @package_path.nil? ||
           (@package_path.respond_to?(:empty?) && @package_path.empty?)
          return @class_name
        end
        
        "#{@package_path}#{PackagePath::SEPARATOR}#{@class_name}"
      end
      
      # Check if this is a qualified name (has a package path).
      #
      # @return [Boolean] true if qualified (has package), false if unqualified
      # @example
      #   QualifiedName.new("Package::Class").qualified? # => true
      #   QualifiedName.new("Class").qualified? # => false
      def qualified?
        !@package_path.nil? && !@package_path.empty?
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

      # Check if this qualified name matches a glob pattern.
      #
      # @param pattern [String] The glob pattern to match against
      # @return [Boolean] true if matches
      # @example
      #   qname = QualifiedName.new("Package1::Package2::ClassName")
      #   qname.matches_glob?("Package1::*::ClassName") # => true
      def matches_glob?(pattern)
        # Create a full path for matching (package + class)
        full_segments = if @package_path.respond_to?(:segments) && !@package_path.segments.empty?
                          @package_path.segments + [@class_name]
                        else
                          [@class_name]
                        end
        
        full_path = PackagePath.new(full_segments)
        full_path.matches_glob?(pattern)
      end

      # Create a new qualified name with a different package path.
      #
      # @param new_package_path [PackagePath] The new package path
      # @return [QualifiedName] A new qualified name with the package replaced
      # @example
      #   qname = QualifiedName.new("Package1::ClassName")
      #   new_path = PackagePath.new("Package2")
      #   qname.with_package(new_path) # => QualifiedName("Package2::ClassName")
      def with_package(new_package_path)
        if new_package_path.respond_to?(:empty?) && new_package_path.empty?
          self.class.new(@class_name)
        else
          self.class.new("#{new_package_path}#{PackagePath::SEPARATOR}#{@class_name}")
        end
      end

      # Get the relative qualified name from a base package path.
      #
      # @param base_path_string [String] The base package path
      # @return [QualifiedName] The relative qualified name, or self if not relative
      # @example
      #   qname = QualifiedName.new("ModelRoot::i-UR::urf::UrbanPlanningArea")
      #   qname.relative_to("ModelRoot::i-UR")
      #   # => QualifiedName("urf::UrbanPlanningArea")
      def relative_to(base_path_string)
        relative_path = @package_path.relative_to(base_path_string)
        
        # If package path didn't change, return self
        return self if relative_path == @package_path
        
        # Otherwise create new qualified name with relative path
        if relative_path.respond_to?(:empty?) && relative_path.empty?
          self.class.new(@class_name)
        else
          self.class.new("#{relative_path}#{PackagePath::SEPARATOR}#{@class_name}")
        end
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
