# frozen_string_literal: true

require "benchmark"
require_relative "../qea"
require_relative "../xmi"

module Lutaml
  module Qea
    # Performance benchmarking utilities for comparing QEA vs XMI parsing
    class Benchmark
      class << self
        # Compare QEA and XMI parsing performance
        #
        # @param qea_path [String] Path to QEA file
        # @param xmi_path [String] Path to XMI file
        # @return [Hash] Benchmark results
        #
        # @example
        #   results = Lutaml::Qea::Benchmark.compare(
        #     "model.qea",
        #     "model.xmi"
        #   )
        #   puts "QEA: #{results[:qea][:time]}s"
        #   puts "XMI: #{results[:xmi][:time]}s"
        #   puts "Speedup: #{results[:speedup]}x"
        def compare(qea_path, xmi_path)
          qea_result = measure_qea(qea_path)
          xmi_result = measure_xmi(xmi_path)

          speedup = if qea_result[:time].positive?
                      (xmi_result[:time] / qea_result[:time]).round(2)
                    else
                      0
                    end

          {
            qea: qea_result,
            xmi: xmi_result,
            speedup: speedup,
            improvement_percent: ((speedup - 1) * 100).round(1),
          }
        end

        # Measure QEA parsing performance
        #
        # @param path [String] Path to QEA file
        # @return [Hash] Performance metrics
        #
        # @example
        #   result = Lutaml::Qea::Benchmark.measure_qea("model.qea")
        #   puts "Time: #{result[:time]}s"
        #   puts "Packages: #{result[:stats][:packages]}"
        def measure_qea(path)
          unless File.exist?(path)
            return { error: "File not found: #{path}" }
          end

          result = {
            file: path,
            file_size_mb: (File.size(path) / 1024.0 / 1024.0).round(2),
            format: "QEA",
          }

          # Measure parsing time
          document = nil
          time = ::Benchmark.realtime do
            document = Lutaml::Qea.parse(path)
          end

          result[:time] = time.round(3)
          result[:stats] = {
            packages: document.packages&.size || 0,
            classes: document.classes&.size || 0,
            associations: document.associations&.size || 0,
            diagrams: document.diagrams&.size || 0,
          }

          # Calculate throughput
          if result[:file_size_mb].positive? && time.positive?
            result[:throughput_mb_per_sec] =
              (result[:file_size_mb] / time).round(2)
          end

          result
        rescue StandardError => e
          {
            error: e.message,
            file: path,
            format: "QEA",
          }
        end

        # Measure XMI parsing performance
        #
        # @param path [String] Path to XMI file
        # @return [Hash] Performance metrics
        #
        # @example
        #   result = Lutaml::Qea::Benchmark.measure_xmi("model.xmi")
        #   puts "Time: #{result[:time]}s"
        def measure_xmi(path)
          unless File.exist?(path)
            return { error: "File not found: #{path}" }
          end

          result = {
            file: path,
            file_size_mb: (File.size(path) / 1024.0 / 1024.0).round(2),
            format: "XMI",
          }

          # Measure parsing time
          document = nil
          time = ::Benchmark.realtime do
            File.open(path) do |file|
              document = Lutaml::Xmi::Parsers::Xml.parse(file)
            end
          end

          result[:time] = time.round(3)
          result[:stats] = {
            packages: document.packages&.size || 0,
            classes: document.classes&.size || 0,
            associations: document.associations&.size || 0,
            diagrams: document.diagrams&.size || 0,
          }

          # Calculate throughput
          if result[:file_size_mb].positive? && time.positive?
            result[:throughput_mb_per_sec] =
              (result[:file_size_mb] / time).round(2)
          end

          result
        rescue StandardError => e
          {
            error: e.message,
            file: path,
            format: "XMI",
          }
        end

        # Format benchmark results for display
        #
        # @param results [Hash] Results from compare method
        # @return [String] Formatted text
        def format_results(results)
          return results[:error] if results[:error]

          output = []
          output << ("=" * 80)
          output << "QEA vs XMI Performance Comparison"
          output << ("=" * 80)
          output << ""

          if results[:qea][:error]
            output << "QEA Error: #{results[:qea][:error]}"
          else
            output << "QEA File:"
            output << "  Path:       #{results[:qea][:file]}"
            output << "  Size:       #{results[:qea][:file_size_mb]} MB"
            output << "  Parse Time: #{results[:qea][:time]}s"
            output << "  Throughput: #{results[:qea][:throughput_mb_per_sec]} MB/s" if results[:qea][:throughput_mb_per_sec]
            output << "  Packages:   #{results[:qea][:stats][:packages]}"
            output << "  Classes:    #{results[:qea][:stats][:classes]}"
          end

          output << ""

          if results[:xmi][:error]
            output << "XMI Error: #{results[:xmi][:error]}"
          else
            output << "XMI File:"
            output << "  Path:       #{results[:xmi][:file]}"
            output << "  Size:       #{results[:xmi][:file_size_mb]} MB"
            output << "  Parse Time: #{results[:xmi][:time]}s"
            output << "  Throughput: #{results[:xmi][:throughput_mb_per_sec]} MB/s" if results[:xmi][:throughput_mb_per_sec]
            output << "  Packages:   #{results[:xmi][:stats][:packages]}"
            output << "  Classes:    #{results[:xmi][:stats][:classes]}"
          end

          output << ""
          output << "Performance Improvement:"
          output << "  QEA is #{results[:speedup]}x faster than XMI"
          output << "  Improvement: #{results[:improvement_percent]}%"
          output << ""

          # Add interpretation
          output << if results[:speedup] >= 10
                      "  ✓ Significant performance improvement with QEA"
                    elsif results[:speedup] >= 5
                      "  ✓ Notable performance improvement with QEA"
                    elsif results[:speedup] >= 2
                      "  ✓ Moderate performance improvement with QEA"
                    else
                      "  ~ Minimal performance difference"
                    end

          output << ("=" * 80)

          output.join("\n")
        end
      end
    end
  end
end
