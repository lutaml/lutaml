# frozen_string_literal: true

module Lutaml
  module Cli
    module Uml
      autoload :BuildCommand, "lutaml/cli/uml/build_command"
      autoload :InfoCommand, "lutaml/cli/uml/info_command"
      autoload :ValidateCommand, "lutaml/cli/uml/validate_command"
      autoload :LsCommand, "lutaml/cli/uml/ls_command"
      autoload :InspectCommand, "lutaml/cli/uml/inspect_command"
      autoload :TreeCommand, "lutaml/cli/uml/tree_command"
      autoload :StatsCommand, "lutaml/cli/uml/stats_command"
      autoload :SearchCommand, "lutaml/cli/uml/search_command"
      autoload :FindCommand, "lutaml/cli/uml/find_command"
      autoload :ExportCommand, "lutaml/cli/uml/export_command"
      autoload :ServeCommand, "lutaml/cli/uml/serve_command"
      autoload :SpaCommand, "lutaml/cli/uml/spa_command"
      autoload :ReplCommand, "lutaml/cli/uml/repl_command"
      autoload :VerifyCommand, "lutaml/cli/uml/verify_command"
      autoload :DiagramCommand, "lutaml/cli/uml/diagram_command"
      autoload :SharedHelpers, "lutaml/cli/uml/shared_helpers"
    end
  end
end
