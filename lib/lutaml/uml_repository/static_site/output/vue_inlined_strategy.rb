# frozen_string_literal: true

require "json"
require "fileutils"

module Lutaml
  module UmlRepository
    module StaticSite
      module Output
        # Generates a single self-contained HTML file with embedded
        # pre-built Vue IIFE, CSS, and JSON data.
        #
        # Matches the pattern used by lutaml-xsd and lutaml-jsonschema:
        # data in window.__SPA_DATA__, Vue app reads it and renders.
        class VueInlinedStrategy < Strategy
          FRONTEND_DIST = File.expand_path(
            "../../../../../frontend/dist", __dir__
          )

          def render(spa_document, search_index)
            FileUtils.mkdir_p(File.dirname(output_path))

            js = read_frontend_asset("app.iife.js")
            css = read_frontend_asset("style.css")

            data_json = build_data_json(spa_document, search_index)
            html = build_html(data_json, js, css)

            File.write(output_path, html)
            output_path
          end

          private

          def read_frontend_asset(filename)
            path = File.join(FRONTEND_DIST, filename)
            return File.read(path) if File.exist?(path)

            raise <<~MSG
              Frontend asset not found: #{path}
              Run `cd frontend && npm install && npm run build` first.
            MSG
          end

          def build_data_json(spa_document, search_index)
            metadata_hash = JSON.parse(spa_document.metadata.to_json)

            # Parse appearance JSON string back into the metadata
            if metadata_hash["appearance"].is_a?(String) && !metadata_hash["appearance"].empty?
              begin
                metadata_hash["appearance"] =
                  JSON.parse(metadata_hash["appearance"])
              rescue StandardError
                metadata_hash.delete("appearance")
              end
            else
              metadata_hash.delete("appearance")
            end

            {
              metadata: metadata_hash,
              packageTree: spa_document.package_tree,
              packages: spa_document.packages,
              classes: spa_document.classes,
              attributes: spa_document.attributes,
              associations: spa_document.associations,
              operations: spa_document.operations,
              diagrams: spa_document.diagrams,
              searchIndex: search_index,
            }.to_json
          end

          def build_html(data_json, js, css)
            meta = config&.metadata
            title = config.ui&.title || meta&.title || "UML Browser"
            description = config.ui&.description || meta&.description || "UML Model Documentation"

            <<~HTML
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>#{title}</title>
                <meta name="description" content="#{description}">
                <meta name="generator" content="lutaml v#{Lutaml::VERSION}">

                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

                <style>
                #{css}
                </style>
              </head>
              <body>
                <div id="app"></div>

                <script>
                window.__SPA_DATA__ = #{data_json};
                </script>
                <script>
                #{js}
                </script>
              </body>
              </html>
            HTML
          end
        end
      end
    end
  end
end
