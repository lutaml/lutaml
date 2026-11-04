# frozen_string_literal: true

require "json"
require "fileutils"

module Lutaml
  module Jsonschema
    module Spa
      class VueInlinedStrategy < OutputStrategy
        FRONTEND_DIST = File.expand_path("../../../../frontend/dist", __dir__)

        def write(json_data)
          FileUtils.mkdir_p(@output_path)

          js = read_frontend_asset("app.iife.js")
          css = read_frontend_asset("style.css")

          html = build_html(json_data, js, css)

          File.write(File.join(@output_path, "index.html"), html)
        end

        private

        def read_frontend_asset(filename)
          path = File.join(FRONTEND_DIST, filename)
          return File.read(path) if File.exist?(path)

          raise Error,
                "Frontend asset not found: #{path}. The installed gem should ship it — reinstall the gem."
        end

        def build_html(json_data, js, css)
          <<~HTML
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>JSON Schema Documentation</title>
              <style>#{css}</style>
            </head>
            <body>
              <div id="app"></div>
              <script>window.SCHEMA_DATA = #{json_data};</script>
              <script>#{js}</script>
            </body>
            </html>
          HTML
        end
      end
    end
  end
end
