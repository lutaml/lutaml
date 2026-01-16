# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "../../uml"

module Lutaml
  module Cli
    module Uml
      # SpaCommand generates static SPA browser for UML models
      class SpaCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name) # rubocop:disable Metrics/MethodLength
          thor_class.long_desc <<-DESC
          Generate a modern, interactive Single Page Application (SPA) for browsing
          UML models. Supports both single-file (all-in-one HTML) and multi-file
          (separate assets) output modes.

          Examples:
            # Single-file SPA (open directly in browser)
            lutaml uml build-spa model.lur -o browser.html

            # Multi-file site (for hosting)
            lutaml uml build-spa model.lur -o dist/ -m multi-file

            # With custom title and minification
            lutaml uml build-spa model.lur -o dist/ --title "My Model" --minify

            # From QEA file
            lutaml uml build-spa model.qea -o browser.html
          DESC

          thor_class.option :output, aliases: "-o", required: true,
                                     desc: "Output path (file for " \
                                           "single-file, directory for " \
                                           "multi-file)"
          thor_class.option :mode, aliases: "-m", default: "single-file",
                                   desc: "Output mode: 'single-file' or " \
                                         "'multi-file'"
          thor_class.option :title, type: :string, default: "UML Model Browser",
                                    desc: "Site title"
          thor_class.option :minify, type: :boolean, default: false,
                                     desc: "Minify HTML/CSS/JS output"
          thor_class.option :theme, type: :string, default: "light",
                                    desc: "Default theme: 'light' or 'dark'"
        end

        def run(input_path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          validate_input(input_path)

          mode = determine_mode
          output_path = validate_output_path(mode)

          OutputFormatter.progress("Loading repository from #{input_path}")
          repository = load_repository(input_path)
          OutputFormatter.progress_done

          OutputFormatter.progress("Generating SPA (#{mode} mode)")
          generate_spa(repository, mode, output_path)
          OutputFormatter.progress_done

          display_success_message(mode, output_path)
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("SPA generation failed: #{e.message}")
          puts "Backtrace:"
          puts e.backtrace.first(20).join("\n")
          raise Thor::Error, "SPA generation failed: #{e.message}"
        end

        private

        def validate_input(input_path)
          return if File.exist?(input_path)

          puts OutputFormatter.error("Input file not found: #{input_path}")
          raise Thor::Error, "Input file not found: #{input_path}"
        end

        def detect_mode # rubocop:disable Metrics/MethodLength
          mode_value = options[:mode] || options["mode"] || "single-file"

          case mode_value.downcase
          when "single-file", "single_file", "single"
            :single_file
          when "multi-file", "multi_file", "multi"
            :multi_file
          else
            puts OutputFormatter.error("Invalid mode: #{mode_value}. " \
                                       "Use 'single-file' or 'multi-file'")
            raise Thor::Error,
                  "Invalid mode: #{mode_value}. " \
                  "Use 'single-file' or 'multi-file'"
          end
        end

        def determine_mode # rubocop:disable Metrics/MethodLength
          mode_value = options[:mode] || "single-file"

          case mode_value.to_s.downcase
          when "multi-file", "multi_file", "multifile"
            :multi_file
          when "single-file", "single_file", "singlefile", ""
            :single_file
          else
            puts OutputFormatter.error("Invalid mode: #{mode_value}. " \
                                       "Use 'single-file' or 'multi-file'")
            raise Thor::Error,
                  "Invalid mode: #{mode_value}. " \
                  "Use 'single-file' or 'multi-file'"
          end
        end

        def validate_output_path(mode) # rubocop:disable Metrics/MethodLength
          output = options[:output]

          # For multi-file mode, ensure output is a directory
          if mode == :multi_file && File.extname(output) != ""
            puts OutputFormatter.colorize(
              "Warning: Multi-file mode requires directory output", :yellow
            )
            output_dir = File.dirname(output)
            puts "Using directory: #{output_dir}"
            output_dir
          else
            output
          end
        end

        def load_repository(path)
          ext = File.extname(path).downcase

          case ext
          when ".lur"
            load_from_lur(path)
          when ".qea"
            load_from_qea(path)
          else
            raise "Unsupported file type: #{ext}. Expected .lur or .qea"
          end
        end

        def load_from_lur(path)
          Lutaml::UmlRepository::Repository.from_package(path)
        end

        def load_from_qea(path)
          require_relative "../../qea"

          # Load QEA database
          qea_db = Lutaml::Qea::Services::DatabaseLoader.new(path).load

          # Convert to UML Document using factory
          factory = Lutaml::Qea::Factory::EaToUmlFactory.new(qea_db)
          document = factory.create_document

          # Create repository from document
          Lutaml::UmlRepository::Repository.new(document: document)
        end

        def generate_spa(repository, mode, output_path)
          generation_options = {
            mode: mode,
            output: output_path,
            title: options[:title] || "UML Model Browser",
            minify: options[:minify] || false,
            theme: options[:theme] || "light"
          }

          Lutaml::UmlRepository::StaticSite.generate(repository,
                                                     generation_options)
        end

        def display_success_message(mode, output_path) # rubocop:disable Metrics/MethodLength
          puts ""
          if mode == :single_file
            size_mb = File.size(output_path) / 1024.0 / 1024.0
            puts OutputFormatter.success(
              "Generated single-file SPA: #{output_path} " \
              "(#{'%.2f' % size_mb} MB)",
            )
            puts OutputFormatter.colorize("Open in browser to view", :cyan)
          else
            puts OutputFormatter.success(
              "Generated multi-file site in: #{output_path}",
            )
            puts OutputFormatter.colorize(
              "Open #{output_path}/index.html in browser", :cyan
            )
          end
        end

        def format_size(bytes)
          if bytes < 1024
            "#{bytes} B"
          elsif bytes < 1024 * 1024
            "#{'%.2f' % (bytes / 1024.0)} KB"
          else
            "#{'%.2f' % (bytes / 1024.0 / 1024.0)} MB"
          end
        end
      end
    end
  end
end
