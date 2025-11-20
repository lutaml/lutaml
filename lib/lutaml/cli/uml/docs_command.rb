# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # DocsCommand generates static documentation site
      class DocsCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Generate a static HTML documentation website.

          Examples:
            lutaml uml docs model.lur -o docs/
            lutaml uml docs model.lur -o site/ --title "My UML Model"
          DESC

          thor_class.option :output, aliases: "-o", required: true,
                                     desc: "Output directory"
          thor_class.option :title, type: :string, default: "UML Model Documentation",
                                    desc: "Documentation title"
          thor_class.option :theme, type: :string, default: "light",
                                    desc: "Color theme (light|dark)"
        end

        def run(lur_path)
          unless File.exist?(lur_path)
            puts OutputFormatter.error("Package file not found: #{lur_path}")
            raise Thor::Error, "Package file not found: #{lur_path}"
          end

          OutputFormatter.progress("Loading repository")
          repo = Lutaml::UmlRepository::Repository.from_package(lur_path)
          OutputFormatter.progress_done

          generator = Lutaml::Xmi::DocGenerator.new(repo)

          OutputFormatter.progress("Generating documentation site")
          generator.generate(options[:output],
                             options.to_h.transform_keys(&:to_sym))
          OutputFormatter.progress_done

          puts ""
          puts OutputFormatter.success("Documentation generated in #{options[:output]}")
          puts ""
          puts "Open #{options[:output]}/index.html in a web browser to view."
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Documentation generation failed: #{e.message}")
          raise Thor::Error, "Documentation generation failed: #{e.message}"
        end
      end
    end
  end
end
