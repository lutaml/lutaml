# frozen_string_literal: true

require "json"
require_relative "../output_strategy"

module Lutaml
  module Xsd
    module Spa
      module Strategies
        # VueInlinedStrategy - Generates a single HTML file with Vue app inlined
        #
        # This is the DEFAULT strategy that generates a self-contained HTML file
        # with all CSS and JavaScript embedded directly. This works reliably on
        # all browsers including when opened via file:// protocol.
        #
        # @example
        #   strategy = VueInlinedStrategy.new(
        #     'output/docs.html',
        #     config_loader,
        #     verbose: true
        #   )
        #   files = strategy.generate(data, renderer)
        class VueInlinedStrategy < OutputStrategy
          attr_reader :output_path, :config_loader

          # Initialize Vue inlined strategy
          #
          # @param output_path [String] Output file path
          # @param config_loader [ConfigurationLoader] Configuration loader
          # @param verbose [Boolean] Enable verbose output
          def initialize(output_path, config_loader, verbose: false)
            super(verbose: verbose)
            @output_path = output_path
            @config_loader = config_loader
          end

          # Generate single HTML file with Vue app inlined
          #
          # @param data [Hash] Serialized schema data
          # @param renderer [TemplateRenderer] Template renderer (unused for Vue mode)
          # @return [Array<String>] List containing single file path
          def generate(data, _renderer)
            log "Generating Vue inlined SPA (single HTML with all assets embedded)..."

            # Read pre-built assets
            app_js = read_frontend_asset("app.iife.js")
            app_css = read_frontend_asset("style.css")

            # Build complete HTML document
            html = build_html_document(data, app_js, app_css)

            # Write to file
            prepare_output
            files = [write_file(output_path, html)]

            log "✓ Vue inlined SPA generated: #{output_path}"
            files
          end

          protected

          # Read pre-built frontend asset
          #
          # @param filename [String] Asset filename
          # @return [String] Asset content
          # @raise [RuntimeError] if frontend assets are not built
          def read_frontend_asset(filename)
            asset_path = find_frontend_asset(filename)
            if asset_path && File.exist?(asset_path)
              File.read(asset_path)
            else
              raise(
                "Frontend asset not found: #{filename}. " \
                "Run 'cd frontend && npm install && npm run build' first, " \
                "or use rake build_frontend to build automatically.",
              )
            end
          end

          # Find frontend asset path
          #
          # @param filename [String] Asset filename
          # @return [String, nil] Full path to asset or nil
          def find_frontend_asset(filename)
            # Development: project_root/frontend/dist/ (5 levels up from strategies/)
            # Gem install: lib/frontend/dist/ (same relative path from strategies/)
            path = File.join(__dir__, "..", "..", "..", "..", "..", "frontend",
                             "dist", filename)
            File.exist?(path) ? path : nil
          end

          # Build complete HTML document with embedded Vue app
          #
          # @param data [Hash] Schema data
          # @param app_js [String] JavaScript content
          # @param app_css [String] CSS content
          # @return [String] Complete HTML document
          def build_html_document(data, app_js, app_css)
            schema_data_json = build_schema_json(data)
            metadata = data[:metadata] || {}
            appearance = metadata[:appearance] || {}
            favicon_links = build_favicon_links(appearance)

            <<~HTML
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <meta name="generator" content="lutaml-xsd #{Lutaml::Xsd::VERSION}">
                <meta name="description" content="XSD Schema Documentation">
                <title>#{metadata[:title] || metadata[:name] || 'XSD Schema Documentation'}</title>

                <!-- Favicons -->
                #{favicon_links}

                <!-- Google Fonts -->
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

                <!-- Embedded CSS -->
                <style>
                #{app_css}
                </style>
              </head>
              <body>
                <div id="app"></div>

                <!-- Schema Data -->
                <script>
                window.SCHEMA_DATA = #{schema_data_json.gsub('</', '<\\/')};
                </script>

                <!-- Embedded JavaScript -->
                <script>
                #{app_js}
                </script>
              </body>
              </html>
            HTML
          end

          # Build favicon link tags from appearance config
          #
          # @param appearance [Hash] Appearance config from metadata
          # @return [String] HTML fragment with favicon link tags
          def build_favicon_links(appearance)
            favicons = appearance[:favicon] || appearance["favicon"] || []
            return "" if favicons.empty?

            favicons.map do |favicon|
              attrs = []
              attrs << %(type="#{favicon[:type] || favicon['type']}") if favicon[:type] || favicon["type"]
              attrs << %(sizes="#{favicon[:sizes] || favicon['sizes']}") if favicon[:sizes] || favicon["sizes"]
              attrs << %(rel="#{favicon[:rel] || favicon['rel'] || 'icon'}")
              attrs << %(href="#{favicon[:path] || favicon['path'] || favicon[:url] || favicon['url']}")

              "<link #{attrs.join(' ')}>"
            end.join("\n    ")
          end

          # Build JSON representation of schema data
          #
          # @param data [Hash] Schema data
          # @return [String] JSON string
          def build_schema_json(data)
            # Use compact representation to reduce file size
            json_data = {
              metadata: data[:metadata],
              schemas: data[:schemas],
              namespaces: data[:namespaces],
            }

            json_data.to_json
          end

          # Prepare output directory
          #
          # @return [void]
          def prepare_output
            dir = File.dirname(output_path)
            ensure_directory(dir) unless dir == "."
          end
        end
      end
    end
  end
end
