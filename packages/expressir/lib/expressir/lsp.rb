# frozen_string_literal: true

module Expressir
  # Language Server Protocol support: stdio JSON-RPC transport, open
  # documents, and the workspace view that resolves across schemas.
  module Lsp
    autoload :Document, "#{__dir__}/lsp/document"
    autoload :Workspace, "#{__dir__}/lsp/workspace"
    autoload :Server, "#{__dir__}/lsp/server"
  end
end
