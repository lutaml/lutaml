# frozen_string_literal: true

require "thor"
require_relative "cli/uml_commands"
require_relative "cli/lml_commands"

module Lutaml
  # Main CLI entry point for LutaML
  #
  # This is a pure Thor implementation with no custom routing logic.
  # All commands are organized into subcommands:
  # - uml: UML repository operations (XMI/QEA/LUR files)
  # - diagram: DSL diagram generation (LutaML textual notation)
  # - xmi: Deprecated alias for 'uml'
  class CLI < Thor
    desc "uml SUBCOMMAND", "UML repository operations (XMI/QEA/LUR files)"
    long_desc <<-DESC
      Perform operations on UML repositories from XMI, QEA, or LUR files.

      Available subcommands:
        build     - Build LUR package from XMI or QEA
        validate  - Validate QEA or LUR file
        info      - Show package metadata
        ls        - List elements
        inspect   - Show element details
        tree      - Package hierarchy
        stats     - Statistics
        search    - Full-text search
        find      - Criteria search
        export    - Export data
        docs      - Generate documentation
        serve     - Web UI
        repl      - Interactive shell
        verify    - XMI/QEA equivalence

      Examples:
        lutaml uml build model.qea
        lutaml uml validate model.lur
        lutaml uml ls model.lur
    DESC
    subcommand "uml", Cli::UmlCommands

    desc "lml SUBCOMMAND", "LutaML textual notation operations"
    long_desc <<-DESC
      Perform operations on LutaML textual DSL notation (.lutaml files).

      Available subcommands:
        generate  - Generate diagram from .lutaml DSL file
        validate  - Validate DSL syntax

      Examples:
        lutaml lml generate model.lutaml -o diagram.png
        lutaml lml validate model.lutaml
    DESC
    subcommand "lml", Cli::LmlCommands

    desc "xmi SUBCOMMAND", "UML repository operations (⚠ deprecated, use 'uml')"
    long_desc <<-DESC
      DEPRECATED: This is an alias for 'uml' and will be removed in a future version.
      Please use 'lutaml uml' instead.

      Examples:
        lutaml xmi build model.qea    # Use: lutaml uml build model.qea
        lutaml xmi validate model.lur # Use: lutaml uml validate model.lur
    DESC
    subcommand "xmi", Cli::UmlCommands

    def self.exit_on_failure?
      true
    end
  end
end
