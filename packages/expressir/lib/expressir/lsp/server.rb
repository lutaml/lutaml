# frozen_string_literal: true

require "json"

module Expressir
  module Lsp
    # JSON-RPC 2.0 transport over stdio (or any IO pair) implementing the
    # LSP 3.17 subset: lifecycle, text sync, diagnostics, symbols,
    # definition, references, hover and rename.
    class Server
      SUPPORTED_CHARACTERS = "utf-16"

      def initialize(input: $stdin, output: $stdout)
        @input = input
        @output = output
        @workspace = Workspace.new
        @shutdown = false
        @exit = false
      end

      def run
        while (message = read_message)
          dispatch(message)
          break if @exit
        end
        @shutdown ? 0 : 1
      end

      private

      def dispatch(message)
        method = message["method"]
        return respond_error(message, -32601, "unknown method #{method}") if method.nil?

        case method
        when "initialize" then respond(message, initialize_result)
        when "initialized", "$/cancelRequest" then nil
        when "shutdown"
          @shutdown = true
          respond(message, nil)
        when "exit" then @exit = true
        when "textDocument/didOpen" then did_open(message["params"])
        when "textDocument/didChange" then did_change(message["params"])
        when "textDocument/didSave" then did_save(message["params"])
        when "textDocument/didClose" then did_close(message["params"])
        when "textDocument/documentSymbol"
          respond(message, @workspace.symbols(uri_of(message)))
        when "textDocument/definition"
          respond(message, @workspace.definition(uri_of(message), position_of(message)))
        when "textDocument/references"
          respond(message, @workspace.references(
                             uri_of(message), position_of(message),
                             include_declaration: include_declaration?(message)
                           ))
        when "textDocument/hover"
          respond(message, @workspace.hover(uri_of(message), position_of(message)))
        when "textDocument/prepareRename"
          respond(message, @workspace.prepare_rename(uri_of(message), position_of(message)))
        when "textDocument/rename"
          respond(message, @workspace.rename(
                             uri_of(message), position_of(message),
                             message.dig("params", "newName").to_s
                           ))
        else
          respond_error(message, -32601, "unknown method #{method}") if message["id"]
        end
      rescue StandardError => e
        respond_error(message, -32603, e.message) if message["id"]
      end

      def initialize_result
        {
          "capabilities" => {
            "positionEncoding" => SUPPORTED_CHARACTERS,
            "textDocumentSync" => {
              "openClose" => true,
              "change" => 1,
              "save" => { "includeText" => false },
            },
            "documentSymbolProvider" => true,
            "definitionProvider" => true,
            "referencesProvider" => true,
            "hoverProvider" => true,
            "renameProvider" => { "prepareProvider" => true },
          },
          "serverInfo" => {
            "name" => "expressir-lsp",
            "version" => Expressir::VERSION,
          },
        }
      end

      def did_open(params)
        document = params.fetch("textDocument")
        @workspace.open(uri: document.fetch("uri"),
                        text: document.fetch("text", ""))
        publish_diagnostics(document.fetch("uri"))
      end

      def did_change(params)
        uri = params.dig("textDocument", "uri")
        change = Array(params["contentChanges"]).last || {}
        @workspace.change(uri: uri, text: change.fetch("text", ""))
        publish_diagnostics(uri)
      end

      def did_save(params)
        publish_diagnostics(params.dig("textDocument", "uri"))
      end

      def did_close(params)
        uri = params.dig("textDocument", "uri")
        @workspace.close(uri)
        notify("textDocument/publishDiagnostics",
               "uri" => uri, "diagnostics" => [])
      end

      def publish_diagnostics(uri)
        return unless uri

        notify("textDocument/publishDiagnostics",
               "uri" => uri,
               "diagnostics" => @workspace.diagnostics(uri))
      end

      def uri_of(message)
        message.dig("params", "textDocument", "uri")
      end

      def position_of(message)
        message.dig("params", "position") || { "line" => 0, "character" => 0 }
      end

      def include_declaration?(message)
        message.dig("params", "context", "includeDeclaration") != false
      end

      def respond(message, result)
        write("jsonrpc" => "2.0", "id" => message["id"], "result" => result)
      end

      def respond_error(message, code, text)
        write("jsonrpc" => "2.0", "id" => message["id"],
              "error" => { "code" => code, "message" => text.to_s })
      end

      def notify(method, params)
        write("jsonrpc" => "2.0", "method" => method, "params" => params)
      end

      def read_message
        headers = read_headers
        return nil unless headers

        length = headers["content-length"].to_i
        body = @input.read(length)
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      end

      def read_headers
        headers = {}
        loop do
          line = @input.gets
          return nil unless line

          line = line.sub(/\r?\n\z/, "")
          break if line.empty?

          name, value = line.split(":", 2)
          headers[name.downcase] = value.to_s.strip
        end
        headers
      end

      def write(payload)
        json = JSON.generate(payload)
        @output.write("Content-Length: #{json.bytesize}\r\n\r\n#{json}")
        @output.flush
      end
    end
  end
end
