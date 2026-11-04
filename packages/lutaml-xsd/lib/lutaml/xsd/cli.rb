# frozen_string_literal: true

require "thor"
require_relative "commands/pkg_command"
require_relative "commands/xml_command"
require_relative "commands/build_command"
require_relative "commands/generate_spa_command"

module Lutaml
  module Xsd
    # Main CLI class for lutaml-xsd command-line interface
    # Provides MECE command structure: pkg, xml, build, spa
    class Cli < Thor
      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output"

      desc "pkg SUBCOMMAND", "Package inspection commands"
      long_desc <<~DESC
        Inspect and query schema repository packages.

        Commands:
          ls           - List all schemas in package
          tree         - Show package file tree
          inspect      - Show full package details
          stats        - Display package statistics
          extract      - Extract a schema from package
          coverage     - Analyze schema coverage
          verify       - Verify XSD specification compliance
          metadata     - Manage package metadata
          type         - Query and explore schema types
          search       - Search for types by name or documentation
          namespace    - Explore namespaces
          element      - Explore elements

        Examples:
          lutaml-xsd pkg ls my-schemas.lxr
          lutaml-xsd pkg tree my-schemas.lxr
          lutaml-xsd pkg stats my-schemas.lxr
          lutaml-xsd pkg type find "gml:CodeType" schemas.lxr
          lutaml-xsd pkg search "unit" schemas.lxr
      DESC
      subcommand "pkg", Commands::PkgCommand

      desc "xml SUBCOMMAND", "XML validation commands"
      long_desc <<~DESC
        Validate XML files against XSD schemas.

        Commands:
          validate     - Validate XML instance files

        Examples:
          lutaml-xsd xml validate instance.xml schemas.lxr
          lutaml-xsd xml validate *.xml schemas.lxr
      DESC
      subcommand "xml", Commands::XmlCommand

      desc "build SUBCOMMAND", "Package creation commands"
      long_desc <<~DESC
        Build and manage schema repository packages.

        Commands:
          from-config        - Build package from YAML configuration
          init               - Interactive package initialization
          quick              - Quick build + validate + stats workflow
          auto               - Auto-build with smart caching
          validate           - Validate a package
          validate-resolution - Validate all references are resolved

        Examples:
          lutaml-xsd build from-config config.yml
          lutaml-xsd build init schema.xsd
          lutaml-xsd build quick config.yml
      DESC
      subcommand "build", Commands::BuildCommand

      desc "spa PACKAGE", "Generate interactive SPA documentation"
      long_desc <<~DESC
        Generate interactive HTML Single Page Application documentation from XSD schemas.

        Examples:
          # Generate single-file documentation (works with file://)
          lutaml-xsd spa schemas.lxr --output docs.html

          # Generate documentation with separate asset files (requires HTTP server)
          lutaml-xsd spa schemas.lxr --output docs.html --mode cdn
      DESC
      option :mode,
             type: :string,
             default: "inlined",
             enum: %w[inlined cdn],
             desc: "Output mode: inlined (single HTML file), cdn (separate assets alongside HTML)"
      option :output,
             type: :string,
             required: true,
             desc: "Output file path"
      option :config,
             type: :string,
             desc: "Path to SPA configuration file"
      option :title,
             type: :string,
             desc: "Documentation title"
      def spa(package_path)
        Commands::GenerateSpaCommand.new(package_path, options).run
      end

      desc "version", "Display lutaml-xsd version"
      def version
        puts "lutaml-xsd version #{Lutaml::Xsd::VERSION}"
      end

      # Error handler
      def self.exit_on_failure?
        true
      end
    end
  end
end
