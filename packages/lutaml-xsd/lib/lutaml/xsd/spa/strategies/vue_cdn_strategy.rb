# frozen_string_literal: true

require_relative "../output_strategy"

module Lutaml
  module Xsd
    module Spa
      module Strategies
        # VueCdnStrategy - Generates HTML that loads Vue app from CDN
        #
        # This strategy generates an HTML file that loads Vue.js and the pre-built
        # application assets from CDN/external sources. The resulting HTML is smaller
        # but requires network access and must be served via HTTP (not file://).
        #
        # Note: When opening HTML via file:// protocol, browsers block loading
        # external JS files due to CORS. Use VueInlinedStrategy for local files.
        #
        # @example
        #   strategy = VueCdnStrategy.new(
        #     'output/docs.html',
        #     config_loader,
        #     verbose: true
        #   )
        #   files = strategy.generate(data, renderer)
        class VueCdnStrategy < OutputStrategy
          # Vue 3 CDN URLs
          VUE_CDN_URL = "https://unpkg.com/vue@3.4.21/dist/vue.global.prod.js"
          VUE_ROUTER_CDN_URL = "https://unpkg.com/vue-router@4.3.0/dist/vue-router.global.prod.js"
          PINIA_CDN_URL = "https://unpkg.com/pinia@2.1.7/dist/pinia.iife.prod.js"

          # Default CDN base URL for app assets
          DEFAULT_CDN_BASE = "https://cdn.example.com/lutaml-xsd"

          attr_reader :output_path, :config_loader, :options

          # Initialize Vue CDN strategy
          #
          # @param output_path [String] Output file path
          # @param config_loader [ConfigurationLoader] Configuration loader
          # @param verbose [Boolean] Enable verbose output
          # @param options [Hash] Additional options
          # @option options [String] :cdn_base Base URL for external assets
          def initialize(output_path, config_loader, verbose: false, **options)
            super(verbose: verbose)
            @output_path = output_path
            @config_loader = config_loader
            @options = options
          end

          # Generate HTML file with CDN-loaded Vue app
          #
          # @param data [Hash] Serialized schema data
          # @param renderer [TemplateRenderer] Template renderer (unused for Vue mode)
          # @return [Array<String>] List containing single file path
          def generate(data, _renderer)
            log "Generating Vue CDN SPA (HTML loads Vue from CDN)..."

            # Build complete HTML document
            html = build_html_document(data)

            # Write to file
            prepare_output
            files = [write_file(output_path, html)]

            # Copy assets to output directory
            asset_files = copy_assets

            log "✓ Vue CDN SPA generated: #{output_path}"
            log "  Note: Assets copied to #{output_dir}/app.iife.js and #{output_dir}/style.css"
            log "  Serve via HTTP to load assets correctly (not file://)"

            files + asset_files
          end

          protected

          # Get CDN base URL for assets
          #
          # @return [String] CDN base URL
          def cdn_base
            options[:cdn_base] || DEFAULT_CDN_BASE
          end

          # Get output directory
          #
          # @return [String] Output directory path
          def output_dir
            @output_dir ||= File.dirname(output_path)
          end

          # Build HTML document that loads Vue from CDN
          #
          # @param data [Hash] Schema data
          # @return [String] HTML document
          def build_html_document(data)
            schema_data_json = build_schema_json(data)
            metadata = data[:metadata] || {}
            appearance = metadata[:appearance] || {}
            favicon_links = build_favicon_links(appearance)

            # Determine asset URLs
            app_js_url = cdn_base == DEFAULT_CDN_BASE ? "./app.iife.js" : "#{cdn_base}/app.iife.js"
            app_css_url = cdn_base == DEFAULT_CDN_BASE ? "./style.css" : "#{cdn_base}/style.css"

            <<~HTML
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <meta name="generator" content="lutaml-xsd #{Lutaml::Xsd::VERSION}">
                <meta name="description" content="XSD Schema Documentation">
                <title>#{metadata[:name] || 'XSD Schema Documentation'}</title>

                <!-- Favicons -->
                #{favicon_links}

                <!-- Google Fonts -->
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

                <!-- External CSS -->
                <link rel="stylesheet" href="#{app_css_url}">
              </head>
              <body>
                <div id="app"></div>

                <!-- Schema Data -->
                <script>
                window.SCHEMA_DATA = #{schema_data_json.gsub('</', '<\\/')};
                </script>

                <!-- Vue 3 from CDN -->
                <script src="#{VUE_CDN_URL}"></script>
                <script src="#{VUE_ROUTER_CDN_URL}"></script>
                <script src="#{PINIA_CDN_URL}"></script>

                <!-- External JavaScript -->
                <script src="#{app_js_url}"></script>
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
            json_data = {
              metadata: data[:metadata],
              schemas: data[:schemas],
              namespaces: data[:namespaces],
            }

            json_data.to_json
          end

          # Copy frontend assets to output directory
          #
          # @return [Array<String>] List of copied asset paths
          # @raise [RuntimeError] if frontend assets are not built
          def copy_assets
            files = []
            missing = []

            ["app.iife.js", "style.css"].each do |filename|
              source = find_frontend_asset(filename)
              if source && File.exist?(source)
                dest = File.join(output_dir, filename)
                FileUtils.cp(source, dest)
                log "✓ Copied: #{dest}"
                files << dest
              else
                missing << filename
              end
            end

            unless missing.empty?
              raise(
                "Frontend assets not found: #{missing.join(', ')}. " \
                "Run 'cd frontend && npm install && npm run build' first, " \
                "or use rake build_frontend to build automatically.",
              )
            end

            files
          end

          # Prepare output directory
          #
          # @return [void]
          def prepare_output
            ensure_directory(output_dir)
          end

          # Find frontend asset path
          #
          # @param filename [String] Asset filename
          # @return [String, nil] Full path to asset or nil
          def find_frontend_asset(filename)
            search_paths = [
              File.join(__dir__, "..", "..", "..", "frontend", "dist",
                        filename),
              File.join(Dir.pwd, "frontend", "dist", filename),
              File.join(__dir__, "..", "..", "..", "dist", filename),
            ]

            search_paths.each do |path|
              return path if File.exist?(path)
            end
            nil
          end
        end
      end
    end
  end
end
