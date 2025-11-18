# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # ServeCommand starts interactive web UI
      class ServeCommand
        attr_reader :options

        def initialize(options = {})
          @options = options
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Start a web server with an interactive UI for browsing the model.

          Uses the modern single-page application with JSON API and lunr.js search.

          Examples:
            lutaml uml serve model.lur
            lutaml uml serve model.lur --port 8080
          DESC

          thor_class.option :port, aliases: "-p", type: :numeric, default: 3000,
                                   desc: "Port to listen on"
          thor_class.option :host, aliases: "-h", type: :string, default: "localhost",
                                   desc: "Host to bind to"
        end

        def run(lur_path)
          unless File.exist?(lur_path)
            puts OutputFormatter.error("Package file not found: #{lur_path}")
            exit 1
          end

          puts OutputFormatter.colorize("\n=== Starting Web UI Server ===\n", :cyan)
          puts "Loading repository from: #{lur_path}"
          puts "Server will be available at: http://#{options[:host]}:#{options[:port]}"
          puts "\nPress Ctrl+C to stop the server\n\n"

          Lutaml::Xmi::WebUi::App.serve(lur_path,
                                        port: options[:port],
                                        host: options[:host])
        rescue Interrupt
          puts "\n\n#{OutputFormatter.colorize('Server stopped', :yellow)}"
        rescue StandardError => e
          puts OutputFormatter.error("Server error: #{e.message}")
          puts e.backtrace.first(5).join("\n") if options[:verbose]
          exit 1
        end
      end
    end
  end
end
