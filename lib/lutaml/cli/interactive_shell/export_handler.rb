# frozen_string_literal: true

module Lutaml
  module Cli
    class InteractiveShell
      class ExportHandler < CommandBase
        EXPORT_FORMATS = {
          "csv" => :export_csv,
          "json" => :export_json,
          "yaml" => :export_yaml,
        }.freeze

        def cmd_export(args)
          return warn_no_results if last_results.nil? || last_results.empty?
          return warn_export_usage unless valid_export_args?(args)

          dispatch_export(args[1].downcase, args[2])
        end

        def valid_export_args?(args)
          args.size >= 3 && args[0] == "last"
        end

        def dispatch_export(format, file_path)
          exporter = EXPORT_FORMATS[format]
          if exporter
            public_send(exporter, file_path)
          else
            puts OutputFormatter.error("Unsupported format: #{format}")
          end
        end

        def warn_no_results
          puts OutputFormatter.warning("No results to export")
        end

        def warn_export_usage
          puts OutputFormatter.warning("Usage: export last FORMAT FILE")
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
