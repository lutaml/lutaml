# frozen_string_literal: true

require "json"
require "fileutils"

module Lutaml
  module UmlRepository
    module StaticSite
      module Output
        # Generates a multi-file static site: separate JSON data files
        # and an index.html that loads them.
        class MultiFileStrategy < Strategy
          def render(spa_document, search_index)
            output_dir = output_path
            FileUtils.mkdir_p(output_dir)
            FileUtils.mkdir_p(File.join(output_dir, "data"))

            write_json(File.join(output_dir, "data", "model.json"),
                       spa_document)
            write_json(File.join(output_dir, "data", "search.json"),
                       search_index)

            html = build_index_html
            File.write(File.join(output_dir, "index.html"), html)

            output_dir
          end

          private

          def write_json(path, data)
            json = JSON.pretty_generate(JSON.parse(data.to_json))
            File.write(path, json)
          end

          def build_index_html
            title = config.ui&.title || "UML Browser"
            description = config.ui&.description || "UML Model Documentation"

            <<~HTML
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>#{title}</title>
                <meta name="description" content="#{description}">
                <meta name="generator" content="LutaML Static Site Generator">

                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
              </head>
              <body>
                <div id="app"></div>

                <script>
                window.__SPA_DATA_URL__ = 'data/model.json';
                window.__SPA_SEARCH_URL__ = 'data/search.json';
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
