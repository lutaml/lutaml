# frozen_string_literal: true

require "thor"
require_relative "output_formatter"
require_relative "uml/build_command"
require_relative "uml/info_command"
require_relative "uml/validate_command"
require_relative "uml/ls_command"
require_relative "uml/inspect_command"
require_relative "uml/tree_command"
require_relative "uml/stats_command"
require_relative "uml/search_command"
require_relative "uml/find_command"
require_relative "uml/export_command"
require_relative "uml/docs_command"
require_relative "uml/serve_command"
require_relative "uml/spa_command"
require_relative "uml/repl_command"
require_relative "uml/verify_command"
require_relative "uml/diagram_command"
require_relative "element_identifier"
require_relative "resource_registry"

module Lutaml
  module Cli
    # UmlCommands provides CLI commands for UML repository operations
    #
    # This is the main CLI interface for working with UML models from
    # XMI and QEA files. Follows MECE (Mutually Exclusive, Collectively
    # Exhaustive) principles and Docker-like command conventions.
    #
    # Command categories:
    # - Resource Lifecycle: build, info, validate
    # - Viewing: ls, inspect, tree, stats
    # - Querying: search, find
    # - Output: export, docs, serve
    # - Development: repl, verify
    #
    # This class serves as a thin delegation layer to individual command classes,
    # keeping the Thor integration separate from business logic.
    class UmlCommands < Thor
      # Command aliases for convenience
      map "ls" => :list
      map "t" => :tree

      # ===================================================================
      # RESOURCE LIFECYCLE COMMANDS
      # ===================================================================

      desc "build MODEL", "Build LUR package from XMI or QEA file"
      Uml::BuildCommand.add_options_to(self, :build)
      def build(model_path)
        Uml::BuildCommand.new(options.to_h).run(model_path)
      end

      desc "info LUR", "Show package metadata"
      Uml::InfoCommand.add_options_to(self, :info)
      def info(lur_path)
        Uml::InfoCommand.new(options.to_h).run(lur_path)
      end

      desc "validate FILE", "Validate LUR package or QEA file"
      Uml::ValidateCommand.add_options_to(self, :validate)
      def validate(file_path)
        Uml::ValidateCommand.new(options.to_h).run(file_path)
      end

      # ===================================================================
      # VIEWING COMMANDS
      # ===================================================================

      desc "ls LUR [PATH]", "List elements in repository"
      Uml::LsCommand.add_options_to(self, :list)
      def list(lur_path, path = nil)
        Uml::LsCommand.new(options.to_h).run(lur_path, path)
      end

      desc "inspect LUR ELEMENT", "Show detailed element information"
      Uml::InspectCommand.add_options_to(self, :inspect)
      def inspect(lur_path, element_id)
        Uml::InspectCommand.new(options.to_h).run(lur_path, element_id)
      end

      desc "tree LUR [PATH]", "Show hierarchical tree view"
      Uml::TreeCommand.add_options_to(self, :tree)
      def tree(lur_path, path = nil)
        Uml::TreeCommand.new(options.to_h).run(lur_path, path)
      end

      desc "stats LUR [PATH]", "Show repository statistics"
      Uml::StatsCommand.add_options_to(self, :stats)
      def stats(lur_path, path = nil)
        Uml::StatsCommand.new(options.to_h).run(lur_path, path)
      end

      # ===================================================================
      # QUERY COMMANDS
      # ===================================================================

      desc "search LUR QUERY", "Full-text search in model"
      Uml::SearchCommand.add_options_to(self, :search)
      def search(lur_path, query)
        Uml::SearchCommand.new(options.to_h).run(lur_path, query)
      end

      desc "find LUR", "Find elements by criteria"
      Uml::FindCommand.add_options_to(self, :find)
      def find(lur_path)
        Uml::FindCommand.new(options.to_h).run(lur_path)
      end

      # ===================================================================
      # OUTPUT COMMANDS
      # ===================================================================

      desc "export LUR", "Export to structured formats"
      Uml::ExportCommand.add_options_to(self, :export)
      def export(lur_path)
        Uml::ExportCommand.new(options.to_h).run(lur_path)
      end

      desc "docs LUR", "Generate static documentation site"
      Uml::DocsCommand.add_options_to(self, :docs)
      def docs(lur_path)
        Uml::DocsCommand.new(options.to_h).run(lur_path)
      end

      desc "build-spa INPUT", "Generate interactive SPA browser"
      Uml::SpaCommand.add_options_to(self, :build_spa)
      def build_spa(input_path)
        Uml::SpaCommand.new(options.to_h).run(input_path)
      end

      desc "serve LUR", "Start interactive web UI"
      Uml::ServeCommand.add_options_to(self, :serve)
      def serve(lur_path)
        Uml::ServeCommand.new(options.to_h).run(lur_path)
      end

      desc "diagram ACTION", "Diagram rendering commands"
      Uml::DiagramCommand.add_options_to(self, :diagram)
      def diagram(action, *args)
        Uml::DiagramCommand.new(options.to_h).run(action, *args)
      end

      # ===================================================================
      # DEVELOPMENT COMMANDS
      # ===================================================================

      desc "repl LUR", "Start interactive REPL shell"
      Uml::ReplCommand.add_options_to(self, :repl)
      def repl(lur_path)
        Uml::ReplCommand.new(options.to_h).run(lur_path)
      end

      desc "verify XMI QEA", "Verify XMI/QEA equivalence"
      Uml::VerifyCommand.add_options_to(self, :verify)
      def verify(xmi_path, qea_path)
        Uml::VerifyCommand.new(options.to_h).run(xmi_path, qea_path)
      end

      desc "diagram ACTION", "Diagram rendering commands"
      Uml::DiagramCommand.add_options_to(self, :diagram)
      def diagram(action, *args)
        Uml::DiagramCommand.new(options.to_h).run(action, *args)
      end
    end
  end
end
