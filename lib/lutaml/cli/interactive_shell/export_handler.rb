# frozen_string_literal: true

require_relative "command_base"

module Lutaml
  module Cli
    class InteractiveShell
      class ExportHandler < CommandBase
        def cmd_export(args)
          if last_results.nil? || last_results.empty?
            puts OutputFormatter.warning("No results to export")
            return
          end

          if args.size < 3 || args[0] != "last"
            puts OutputFormatter.warning("Usage: export last FORMAT FILE")
            return
          end

          format = args[1].downcase
          file_path = args[2]

          case format
          when "csv"
            export_csv(file_path)
          when "json"
            export_json(file_path)
          when "yaml"
            export_yaml(file_path)
          else
            puts OutputFormatter.error("Unsupported format: #{format}")
          end
        end

        def export_csv(file_path)
          require "csv"

          CSV.open(file_path, "w") do |csv|
            csv << ["Qualified Name"]
            last_results.each do |qname|
              csv << [qname]
            end
          end

          puts OutputFormatter.success("Exported #{last_results.size} " \
                                       "results to #{file_path}")
        end

        def export_json(file_path)
          require "json"

          File.write(file_path, JSON.pretty_generate(last_results))
          puts OutputFormatter.success("Exported #{last_results.size} " \
                                       "results to #{file_path}")
        end

        def export_yaml(file_path)
          require "yaml"

          File.write(file_path, last_results.to_yaml)
          puts OutputFormatter.success("Exported #{last_results.size} " \
                                       "results to #{file_path}")
        end
      end
    end
  end
end
