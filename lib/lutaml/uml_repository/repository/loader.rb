# frozen_string_literal: true

require_relative "../package_loader"

module Lutaml
  module UmlRepository
    class Repository
      # Handles loading Repository instances from various file formats.
      #
      # Encapsulates all file I/O and format detection logic, keeping the
      # main Repository class focused on querying.
      #
      # @example Load from XMI
      #   repo = Loader.from_xmi('model.xmi')
      #
      # @example Load from LUR package
      #   repo = Loader.from_package('model.lur')
      #
      # @example Auto-detect format
      #   repo = Loader.from_file('model.xmi')
      module Loader
        # Build a Repository from an XMI file.
        #
        # @param xmi_path [String] Path to the XMI file
        # @param options [Hash] Options for parsing
        # @return [Repository]
        def self.from_xmi(xmi_path, options = {})
          document = Lutaml::Parser.parse([File.new(xmi_path)]).first
          indexes = IndexBuilder.build_all(document)
          new(document: document, indexes: indexes, options: options)
        end

        # Build a Repository from an XMI file with lazy index loading.
        #
        # @param xmi_path [String] Path to the XMI file
        # @param options [Hash] Options for parsing
        # @return [LazyRepository]
        def self.from_xmi_lazy(xmi_path, _options = {})
          document = Lutaml::Parser.parse([File.new(xmi_path)]).first
          LazyRepository.new(document: document, lazy: true)
        end

        # Auto-detect file type and load appropriately.
        #
        # @param path [String] Path to the file (.xmi or .lur)
        # @return [Repository]
        # @raise [ArgumentError] If the file type is unknown
        def self.from_file(path)
          case File.extname(path).downcase
          when ".xmi" then from_xmi(path)
          when ".lur" then from_package(path)
          else
            raise ArgumentError,
                  "Unknown file type: #{path}. Expected .xmi or .lur"
          end
        end

        # Smart caching - use LUR if newer than XMI, otherwise rebuild.
        #
        # @param xmi_path [String] Path to the XMI file
        # @param lur_path [String, nil] Path to the LUR package
        # @return [Repository]
        def self.from_file_cached(xmi_path, lur_path: nil)
          lur_path ||= xmi_path.sub(/\.xmi$/i, ".lur")

          if File.exist?(lur_path) && File.mtime(lur_path) >= File.mtime(xmi_path)
            puts "Using cached LUR package: #{lur_path}" if $VERBOSE
            from_package(lur_path)
          else
            puts "Building repository from XMI..." if $VERBOSE
            repo = from_xmi(xmi_path)

            puts "Caching as LUR package: #{lur_path}" if $VERBOSE
            repo.export_to_package(lur_path)
            repo
          end
        end

        # Load a Repository from a LUR package file.
        #
        # @param lur_path [String] Path to the .lur package file
        # @return [Repository]
        def self.from_package(lur_path)
          PackageLoader.load(lur_path)
        end

        # Load a Repository from a LUR package with lazy loading.
        #
        # @param lur_path [String] Path to the .lur package file
        # @return [LazyRepository]
        def self.from_package_lazy(lur_path)
          PackageLoader.load_document_only(lur_path)
        end

        # Auto-detect file type with lazy loading.
        #
        # @param path [String] Path to the file (.xmi or .lur)
        # @return [LazyRepository]
        # @raise [ArgumentError] If the file type is unknown
        def self.from_file_lazy(path)
          case File.extname(path).downcase
          when ".xmi" then from_xmi_lazy(path)
          when ".lur" then from_package_lazy(path)
          else
            raise ArgumentError,
                  "Unknown file type: #{path}. Expected .xmi or .lur"
          end
        end
      end
    end
  end
end
