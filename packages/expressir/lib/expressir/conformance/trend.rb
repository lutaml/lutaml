# frozen_string_literal: true

require "json"

module Expressir
  module Conformance
    # Trended property metrics over a corpus slice: parse rate and
    # format idempotence rate are fractions; the diagnostic rate is the
    # number of Checker notes per parsed file. Per-note-id counts make
    # the report actionable. Published by the nightly conformance
    # workflow as a JSON artifact so the numbers can be trended.
    class Trend
      def self.measure(files)
        report = {
          "files" => files.size,
          "parsed" => 0,
          "parse_failed" => 0,
          "measurement_failed" => 0,
          "idempotent" => 0,
          "not_idempotent" => 0,
          "notes" => 0,
          "errors" => 0,
          "warnings" => 0,
          "note_ids" => {},
        }
        files.each do |path|
          measure_file(path, report)
        end
        report.merge!(
          "parse_rate" => rate(report["parsed"], report["files"]),
          "idempotence_rate" => rate(report["idempotent"], report["parsed"]),
          "diagnostic_rate" => rate(report["notes"], report["parsed"]),
        )
        report
      end

      def self.run(files, output:)
        report = measure(files)
        File.write(output, "#{JSON.pretty_generate(report)}\n")
        report
      end

      def self.measure_file(path, report)
        repository = parse_file(path)
        unless repository
          report["parse_failed"] += 1
          return
        end
        report["parsed"] += 1
        measure_properties(repository, report)
      end
      private_class_method :measure_file

      def self.parse_file(path)
        Expressir::Express::Parser.from_exp(File.read(path))
      rescue StandardError
        nil
      end
      private_class_method :parse_file

      def self.measure_properties(repository, report)
        schema = Array(repository.schemas).first
        if schema && idempotent?(schema)
          report["idempotent"] += 1
        else
          report["not_idempotent"] += 1
        end
        notes = Expressir::Express::Checker.new(
          Expressir::Model::Repository.new(files: [repository]),
        ).check.notes
        report["notes"] += notes.size
        notes.each do |note|
          report[note.severity == :error ? "errors" : "warnings"] += 1
          report["note_ids"][note.id.to_s] =
            report["note_ids"].fetch(note.id.to_s, 0) + 1
        end
      rescue StandardError
        report["measurement_failed"] += 1
      end
      private_class_method :measure_properties

      def self.idempotent?(schema)
        once = Expressir::Express::Formatter.format(schema)
        reparsed = Expressir::Express::Parser.from_exp(once)
        twice = Expressir::Express::Formatter.format(reparsed.schemas.first)
        once == twice
      rescue StandardError
        false
      end
      private_class_method :idempotent?

      def self.rate(numerator, denominator)
        return 0.0 if denominator.zero?

        (numerator.to_f / denominator).round(4)
      end
      private_class_method :rate
    end
  end
end
