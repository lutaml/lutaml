# frozen_string_literal: true

module Expressir
  module Commands
    # `expressir doctor` (TODO.compat/02): assess a workspace for
    # expressir readiness — which schemas parse, which instance
    # datasets load, which mapping files bind — and optionally emit a
    # starter schema manifest for the schemas it found.
    class Doctor < Base
      Report = Struct.new(:schemas, :instances, :mappings, keyword_init: true)

      def run(path)
        raise Thor::Error, "#{path} is not a directory" unless File.directory?(path)

        report = Report.new(schemas: [], instances: [], mappings: [])
        Dir.glob("#{path}/**/*.exp").each { |f| probe_schema(f, report) }
        Dir.glob("#{path}/**/*.p21").each { |f| probe_instance(f, report) }
        Dir.glob("#{path}/**/mapping*.yaml").each { |f| probe_mapping(f, report) }

        emit_manifest(path, report) if options[:emit_manifest]
        print_report(report)
      end

      private

      def probe_schema(file, report)
        repo = Expressir::Express::Parser.from_file(file, skip_references: true)
        report.schemas << { path: file, schemas: repo.schemas.size,
                            entities: repo.schemas.sum { |s| s.entities.size } }
      rescue StandardError => e
        report.schemas << { path: file, error: e.message[0, 160] }
      end

      def probe_instance(file, report)
        pop = Expressir::P21::Parser.parse(File.read(file))
        report.instances << { path: file, instances: pop.instances.size }
      rescue StandardError => e
        report.instances << { path: file, error: e.message[0, 160] }
      end

      def probe_mapping(file, report)
        doc = Expressir::Mapping.load_file(file)
        report.mappings << { path: file,
                             elements: doc.ae.size + doc.sc.size }
      rescue StandardError => e
        report.mappings << { path: file, error: e.message[0, 160] }
      end

      def emit_manifest(_path, report)
        return unless options[:emit_manifest]

        manifest_path = options[:emit_manifest] == true ? "manifest.yml" : options[:emit_manifest]
        ready = report.schemas.select { |s| s[:schemas] }
        File.write(manifest_path, {
          "schema" => ready.first&.dig(:path) || "schema.exp",
          "release" => "workspaces",
          "files" => ready.map { |s| s[:path] },
        }.to_yaml)
        say "starter manifest written to #{manifest_path}"
      end

      def print_report(report)
        report.schemas.each { |s| print_entry("schema", s) }
        report.instances.each { |s| print_entry("instance", s) }
        report.mappings.each { |s| print_entry("mapping", s) }
        ready = report.schemas.count { |s| s[:schemas] } +
          report.instances.count { |s| s[:instances] } +
          report.mappings.count { |s| s[:elements] }
        say "ready: #{ready} file(s)"
      end

      def print_entry(kind, entry)
        if entry[:error]
          say "UNREADABLE #{kind} #{entry[:path]}: #{entry[:error]}"
        else
          say "ready #{kind} #{entry[:path]}"
        end
      end
    end
  end
end
