# frozen_string_literal: true

require "sinatra/base"
require "json"
require "liquid"
require_relative "../static_site"

module Lutaml
  module Xmi
    module WebUi
      # Refactored Sinatra web application using shared SPA code.
      #
      # This version serves the same UI as the static SPA generator but with
      # JSON API endpoints instead of embedded data. Shares Liquid templates
      # with the static site generator.
      #
      # @example Starting the server
      #   Lutaml::Xmi::WebUi::App.serve("model.lur", port: 3000)
      class App < Sinatra::Base
        enable :logging

        # Serve the SPA (using shared Liquid template)
        get "/" do
          content_type :html

          # Use the same multi_file.liquid template as static generator
          # but with apiMode: true to use JSON endpoints
          template_path = File.join(__dir__, "..", "..", "..", "templates",
                                    "static_site")
          Liquid::Template.file_system = Liquid::LocalFileSystem.new(template_path)

          template_content = File.read(File.join(template_path,
                                                 "multi_file.liquid"))
          template = Liquid::Template.parse(template_content)

          context = {
            "config" => {
              "mode" => "multi_file",
              "title" => "UML Repository Explorer (Live)",
              "description" => "Live browser for UML models",
              "apiMode" => true, # KEY: Use API endpoints instead of static JSON
              "theme" => "light",
            },
            "buildInfo" => {
              "timestamp" => Time.now.utc.iso8601,
              "generator" => "LutaML Live Web UI v2.0",
            },
          }

          template.render(context)
        end

        # API: Full data model (replaces data/model.json in static mode)
        get "/api/data" do
          content_type :json

          # Use shared DataTransformer
          transformer = StaticSite::DataTransformer.new(repository)
          transformer.transform.to_json
        end

        # API: Search index (replaces data/search.json in static mode)
        get "/api/search/index" do
          content_type :json

          # Use shared SearchIndexBuilder
          builder = StaticSite::SearchIndexBuilder.new(repository)
          builder.build.to_json
        end

        # API: Package details (on-demand, optional optimization)
        get "/api/packages/:id" do
          content_type :json
          params[:id]

          # Find package by generated ID
          # This would require reverse lookup from ID to package
          # For now, use the full data endpoint
          halt 501,
               { error: "On-demand package loading not yet implemented. Use /api/data" }.to_json
        end

        # API: Class details (on-demand, optional optimization)
        get "/api/classes/:id" do
          content_type :json
          params[:id]

          # Find class by generated ID
          # This would require reverse lookup from ID to class
          # For now, use the full data endpoint
          halt 501,
               { error: "On-demand class loading not yet implemented. Use /api/data" }.to_json
        end

        # Legacy API: Search (for backward compatibility)
        get "/api/search" do
          content_type :json
          query = params[:q]

          if query.nil? || query.empty?
            halt 400,
                 { error: "Query required" }.to_json
          end

          # Use repository's built-in search
          types = params[:types]&.split(",")&.map(&:to_sym) || %i[class
                                                                  attribute association]
          results = repository.search(query, types: types)

          {
            query: query,
            results: format_legacy_search_results(results),
          }.to_json
        end

        # Legacy API: Statistics (for backward compatibility)
        get "/api/statistics" do
          content_type :json
          repository.statistics.to_json
        end

        # Start the web server
        def self.serve(lur_path, port: 3000, host: "localhost")
          repo = if File.extname(lur_path) == ".lur"
                   UmlRepository.from_package(lur_path)
                 else
                   UmlRepository.from_xmi(lur_path)
                 end

          set :repository, repo
          set :port, port
          set :bind, host

          puts ""
          puts "╔═══════════════════════════════════════════════════════════╗"
          puts "║        LutaML UML Browser - Live Mode (v2.0)            ║"
          puts "╚═══════════════════════════════════════════════════════════╝"
          puts ""
          puts "  Loading: #{File.basename(lur_path)}"
          puts "  Server:  http://#{host}:#{port}"
          puts ""
          puts "  Features:"
          puts "    • Live data via JSON API"
          puts "    • Same UI as static SPA"
          puts "    • Full-text search with lunr.js"
          puts "    • Dark/light themes"
          puts "    • Responsive design"
          puts ""
          puts "  Press Ctrl+C to stop"
          puts ""
          puts "─" * 60
          puts ""

          run!
        end

        private

        # Get the repository from settings
        def repository
          settings.repository
        end

        # Format search results for legacy API compatibility
        def format_legacy_search_results(results)
          formatted = {}

          results.each do |type, items|
            formatted[type] = items.map do |item|
              case type
              when :class
                {
                  type: "class",
                  qualified_name: item.name, # Simplified
                  name: item.name,
                  class_type: item.class.name.split("::").last,
                }
              when :attribute
                {
                  type: "attribute",
                  name: item[:attribute].name,
                  attribute_type: item[:attribute].type,
                  owner_name: item[:owner].name,
                }
              when :association
                {
                  type: "association",
                  name: item.name,
                  id: item.xmi_id,
                }
              end
            end
          end

          formatted
        end
      end
    end
  end
end
