# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # ReplCommand starts interactive REPL shell
      class ReplCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Start an interactive REPL for exploring the model.

          Examples:
            lutaml uml repl model.lur
            lutaml uml repl model.lur --no-color
          DESC

          thor_class.option :color, type: :boolean, default: true,
                                    desc: "Enable colored output"
          thor_class.option :icons, type: :boolean, default: true,
                                    desc: "Enable icons in output"
        end

        def run(lur_path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          unless File.exist?(lur_path)
            puts OutputFormatter.error("Package file not found: #{lur_path}")
            raise Thor::Error, "Package file not found: #{lur_path}"
          end

          config = {
            color: options[:color],
            icons: options[:icons],
          }

          shell = InteractiveShell.new(lur_path, config: config)
          shell.start
        rescue StandardError => e
          puts OutputFormatter.error("Shell error: #{e.message}")
          raise Thor::Error, "Shell error: #{e.message}"
        end
      end
    end
  end
end
