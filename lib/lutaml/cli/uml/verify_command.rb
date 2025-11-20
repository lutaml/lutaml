# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # VerifyCommand verifies XMI/QEA equivalence
      class VerifyCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Verify that QEA and XMI files contain equivalent information.

          Examples:
            lutaml uml verify model.xmi model.qea
            lutaml uml verify model.xmi model.qea --report report.json
          DESC

          thor_class.option :report, type: :string, desc: "Save report to file"
          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|json|yaml)"
        end

        def run(xmi_path, qea_path)
          unless File.exist?(xmi_path)
            puts OutputFormatter.error("XMI file not found: #{xmi_path}")
            raise Thor::Error, "XMI file not found: #{xmi_path}"
          end

          unless File.exist?(qea_path)
            puts OutputFormatter.error("QEA file not found: #{qea_path}")
            raise Thor::Error, "QEA file not found: #{qea_path}"
          end

          puts OutputFormatter.colorize(
            "\n=== XMI/QEA Equivalence Verification ===\n", :cyan
          )
          puts "XMI File: #{xmi_path}"
          puts "QEA File: #{qea_path}"
          puts ""

          OutputFormatter.progress("Verifying equivalence")
          verifier = Lutaml::Qea::Verification::DocumentVerifier.new

          begin
            result = verifier.verify(xmi_path, qea_path)
            OutputFormatter.progress_done
          rescue StandardError => e
            OutputFormatter.progress_done(success: false)
            puts OutputFormatter.error("Verification failed: #{e.message}")
            raise Thor::Error, "Verification failed: #{e.message}"
          end

          display_verification_result(result)

          if options[:report]
            save_verification_report(result, options[:report])
          end

          # Exit with appropriate status
          if options[:strict] && !result.equivalent?
            puts ""
            puts OutputFormatter.error("Verification FAILED")
            raise Thor::Error, "Verification FAILED"
          elsif result.equivalent?
            puts ""
            puts OutputFormatter.success("Verification PASSED")
          end
        end

        private

        def display_verification_result(result)
          puts result.summary

          if result.critical_issues.any?
            puts "\n#{OutputFormatter.colorize('Critical Issues:', :red)}"
            result.critical_issues.each do |issue|
              puts "  ✗ #{issue}"
            end
          end
        end

        def save_verification_report(result, report_path)
          report_data = result.to_report
          ext = File.extname(report_path).downcase
          report_format = case ext
                          when ".json" then :json
                          when ".yaml", ".yml" then :yaml
                          else :json
                          end

          File.write(report_path,
                     OutputFormatter.format(report_data, format: report_format))
          puts OutputFormatter.success("Report saved: #{report_path}")
        end
      end
    end
  end
end
