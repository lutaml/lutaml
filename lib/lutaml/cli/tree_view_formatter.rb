# frozen_string_literal: true

require "paint"

module Lutaml
  module Cli
    # TreeViewFormatter formats UML repository contents as a colored tree
    class TreeViewFormatter
      # Color scheme for different element types
      COLORS = {
        package: :cyan,
        class: :green,
        interface: :magenta,
        enumeration: :yellow,
        attribute: "#FFD700",  # Light Yellow/Gold
        operation: "#87CEEB",  # Light Blue/Sky Blue
        association: :white,
        diagram: "#DDA0DD",    # Light Magenta/Plum
        statistics: "#ADD8E6", # Light Cyan
      }.freeze

      # Icons for different element types
      ICONS = {
        package: "📦",
        class: "📦",
        interface: "🔌",
        enumeration: "🔢",
        attribute: "🔹",
        operation: "🔧",
        association: "🔗",
        diagram: "📊",
      }.freeze

      # Tree drawing characters
      TREE_CHARS = {
        vertical: "│",
        branch: "├──",
        last_branch: "└──",
        space: "   ",
        continuation: "│  ",
      }.freeze

      def initialize(options = {})
        @max_depth = options[:max_depth]
        @show_attributes = options.fetch(:show_attributes, true)
        @show_operations = options.fetch(:show_operations, true)
        @show_associations = options.fetch(:show_associations, false)
        @no_color = options.fetch(:no_color, false)
        @current_depth = 0
      end

      # Format the entire repository as a tree
      #
      # @param repository [Lutaml::UmlRepository::Repository] The repository to format
      # @return [String] Formatted tree output
      def format(repository)
        output = []

        # Start with ModelRoot
        output << colorize("ModelRoot", :package)

        # Get all top-level packages
        root_packages = repository.list_packages("ModelRoot", recursive: false)

        root_packages.each_with_index do |pkg, idx|
          is_last = idx == root_packages.size - 1
          output << format_package(pkg, repository, 0, is_last, "")
        end

        # Add statistics at the end
        output << ""
        output << format_statistics(repository.statistics)

        output.join("\n")
      end

      private

      # Format a package node
      def format_package(package, repository, depth, is_last, prefix)
        return "" if @max_depth && depth >= @max_depth

        output = []
        pkg_name = package.name || "(unnamed)"

        # Package line
        connector = is_last ? TREE_CHARS[:last_branch] : TREE_CHARS[:branch]
        icon = ICONS[:package]
        output << "#{prefix}#{connector} #{icon} #{colorize(pkg_name,
                                                            :package)}"

        # Update prefix for children
        child_prefix = prefix + (is_last ? TREE_CHARS[:space] : TREE_CHARS[:continuation])

        # Get package path for this package
        pkg_path = find_package_path(repository, package)
        return output.join("\n") unless pkg_path

        # Collect all children
        children = []

        # Add sub-packages
        sub_packages = repository.list_packages(pkg_path, recursive: false)
        children.concat(sub_packages.map { |p| { type: :package, obj: p } })

        # Add classes
        classes = repository.classes_in_package(pkg_path, recursive: false)
        children.concat(classes.map { |c| { type: :class, obj: c } })

        # Add diagrams if at top level
        if depth.zero?
          diagrams = repository.diagrams_in_package(pkg_path)
          children.concat(diagrams.map { |d| { type: :diagram, obj: d } })
        end

        # Format each child
        children.each_with_index do |child, idx|
          is_last_child = idx == children.size - 1

          case child[:type]
          when :package
            output << format_package(child[:obj], repository, depth + 1,
                                     is_last_child, child_prefix)
          when :class
            output << format_class(child[:obj], repository, depth + 1,
                                   is_last_child, child_prefix, pkg_path)
          when :diagram
            output << format_diagram(child[:obj], depth + 1,
                                     is_last_child, child_prefix)
          end
        end

        output.join("\n")
      end

      # Format a class node
      def format_class(klass, repository, depth, is_last, prefix, package_path)
        return "" if @max_depth && depth >= @max_depth

        output = []
        class_name = klass.name || "(unnamed)"

        # Determine class type
        type = determine_class_type(klass)
        icon = ICONS[type] || ICONS[:class]
        color = COLORS[type] || COLORS[:class]

        # Class line
        connector = is_last ? TREE_CHARS[:last_branch] : TREE_CHARS[:branch]
        type_label = type == :class ? "Class" : type.to_s.capitalize
        output << "#{prefix}#{connector} #{icon} #{colorize(class_name,
                                                            color)} (#{type_label})"

        # Update prefix for children
        child_prefix = prefix + (is_last ? TREE_CHARS[:space] : TREE_CHARS[:continuation])

        # Collect children
        children = []

        # Add attributes
        if @show_attributes && klass.respond_to?(:attributes) && klass.attributes
          children.concat(klass.attributes.map do |a|
            { type: :attribute, obj: a }
          end)
        end

        # Add operations
        if @show_operations && klass.respond_to?(:operations) && klass.operations
          children.concat(klass.operations.map do |o|
            { type: :operation, obj: o }
          end)
        end

        # Add associations
        if @show_associations
          qualified_name = "#{package_path}::#{class_name}"
          associations = repository.associations_of(qualified_name)
          children.concat(associations.map do |a|
            { type: :association, obj: a }
          end)
        end

        # Format each child
        children.each_with_index do |child, idx|
          is_last_child = idx == children.size - 1

          case child[:type]
          when :attribute
            output << format_attribute(child[:obj], depth + 1, is_last_child,
                                       child_prefix)
          when :operation
            output << format_operation(child[:obj], depth + 1, is_last_child,
                                       child_prefix)
          when :association
            output << format_association(child[:obj], depth + 1, is_last_child,
                                         child_prefix)
          end
        end

        output.join("\n")
      end

      # Format an attribute node
      def format_attribute(attr, depth, is_last, prefix)
        return "" if @max_depth && depth >= @max_depth

        attr_name = attr.name || "(unnamed)"
        attr_type = attr.type || "Unknown"

        connector = is_last ? TREE_CHARS[:last_branch] : TREE_CHARS[:branch]
        icon = ICONS[:attribute]

        "#{prefix}#{connector} #{icon} #{colorize(
          "#{attr_name} : #{attr_type}", :attribute
        )}"
      end

      # Format an operation node
      def format_operation(op, depth, is_last, prefix)
        return "" if @max_depth && depth >= @max_depth

        op_name = op.name || "(unnamed)"

        connector = is_last ? TREE_CHARS[:last_branch] : TREE_CHARS[:branch]
        icon = ICONS[:operation]

        "#{prefix}#{connector} #{icon} #{colorize("#{op_name}()", :operation)}"
      end

      # Format an association node
      def format_association(assoc, depth, is_last, prefix)
        return "" if @max_depth && depth >= @max_depth

        assoc_name = assoc.name || "(unnamed)"
        target = if assoc.respond_to?(:member_end) && assoc.member_end&.first
                   assoc.member_end.first.xmi_type || "Unknown"
                 else
                   "Unknown"
                 end

        connector = is_last ? TREE_CHARS[:last_branch] : TREE_CHARS[:branch]
        icon = ICONS[:association]

        "#{prefix}#{connector} #{icon} #{colorize("#{assoc_name} → #{target}",
                                                  :association)}"
      end

      # Format a diagram node
      def format_diagram(diagram, depth, is_last, prefix)
        return "" if @max_depth && depth >= @max_depth

        diag_name = diagram.name || "(unnamed)"

        connector = is_last ? TREE_CHARS[:last_branch] : TREE_CHARS[:branch]
        icon = ICONS[:diagram]

        "#{prefix}#{connector} #{icon} #{colorize(diag_name, :diagram)}"
      end

      # Format statistics section
      def format_statistics(stats)
        output = []
        output << colorize("📊 Statistics", :statistics)
        output << "#{TREE_CHARS[:branch]} Total Packages: #{stats[:total_packages]}"
        output << "#{TREE_CHARS[:branch]} Total Classes: #{stats[:total_classes]}"
        output << "#{TREE_CHARS[:last_branch]} Total Diagrams: #{stats[:total_diagrams]}"
        output.join("\n")
      end

      # Determine class type (class, interface, enumeration)
      def determine_class_type(klass)
        return :enumeration if klass.class.name&.include?("Enum")
        return :interface if klass.respond_to?(:stereotype) &&
          klass.stereotype&.downcase == "interface"

        :class
      end

      # Find package path for a package object
      def find_package_path(repository, package)
        repository.indexes[:package_paths].each do |path, pkg|
          return path if pkg == package
        end
        nil
      end

      # Colorize text if colors are enabled
      def colorize(text, color_key)
        return text if @no_color

        color = COLORS[color_key]
        return text unless color

        Paint[text, color]
      end
    end
  end
end
