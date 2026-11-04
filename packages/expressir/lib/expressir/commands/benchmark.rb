module Expressir
  module Commands
    class Benchmark < Base
      def run(path)
        configure_benchmarking

        if [".yml", ".yaml"].include?(File.extname(path).downcase)
          benchmark_from_manifest(path)
        else
          benchmark_file(path)
        end
      end

      private

      def configure_benchmarking
        Expressir.configuration.benchmark_enabled = true
        Expressir.configuration.benchmark_ips = options[:ips]
        Expressir.configuration.benchmark_verbose = options[:verbose]
        Expressir.configuration.benchmark_save = options[:save]
        Expressir.configuration.benchmark_format = options[:format] if options[:format]
      end

      def benchmark_file(path)
        say "Express Schema Loading Benchmark"
        say "--------------------------------"

        repository = Expressir::Benchmark.measure_file(path) do
          Expressir::Express::Parser.from_file(path)
        end

        if repository
          say "Loaded #{repository.schemas.size} schemas"
        else
          say "Failed to load schema"
        end
      end

      def benchmark_from_manifest(manifest_path)
        say "Express Schema Loading Benchmark from Manifest"
        say "--------------------------------"

        # Load schema manifest
        manifest = Expressir::SchemaManifest.from_file(manifest_path)
        schema_files = manifest.schemas.map(&:path)

        say "Manifest File: #{manifest_path}"
        say "Number of schemas in list: #{schema_files.size}"
        say "--------------------------------"

        # Load the schemas
        Expressir::Benchmark.measure_collection(schema_files) do |file|
          repository = Expressir::Express::Parser.from_file(file)
          repository.schemas
        end
      end
    end
  end
end
