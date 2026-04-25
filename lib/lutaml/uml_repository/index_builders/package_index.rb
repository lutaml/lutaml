# frozen_string_literal: true

module Lutaml
  module UmlRepository
    class IndexBuilder
      # Build the package path index
      #
      # Creates a hash mapping package paths to Package objects:
      #   "ModelRoot" => Package{},
      #   "ModelRoot::i-UR" => Package{},
      #   "ModelRoot::i-UR::urf" => Package{}
      # @api public
      def build_package_path_index
        # Add root package if it exists
        @package_paths[ROOT_PACKAGE_NAME] = @document if @document

        # Traverse all packages recursively
        traverse_packages(@document.packages,
                          parent_path: ROOT_PACKAGE_NAME) do |package, path|
          @package_paths[path] = package
          @package_to_path[package.xmi_id] = path if package.xmi_id
        end
      end

      # Traverse packages recursively, yielding each package with its path
      #
      # @param packages [Array<Lutaml::Uml::Package>] Packages to traverse
      # @param parent_path [String, nil] Parent package path
      # @yield [package, path] Yields each package with its full path
      def traverse_packages(packages, parent_path: nil, &block)
        return unless packages

        packages.each do |package|
          path = build_package_path(package.name, parent_path)
          yield package, path if block

          # Recursively traverse nested packages
          if package.packages
            traverse_packages(package.packages, parent_path: path,
                              &block)
          end
        end
      end

      # Build a package path from a package name and parent path
      #
      # @param name [String] Package name
      # @param parent_path [String, nil] Parent package path
      # @return [String] Full package path
      def build_package_path(name, parent_path)
        return name unless parent_path

        "#{parent_path}::#{name}"
      end
    end
  end
end
