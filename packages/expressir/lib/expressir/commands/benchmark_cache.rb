module Expressir
  module Commands
    class BenchmarkCache < Base
      def run(path)
        configure_benchmarking

        # Run benchmarks with cache
        cache_path = options[:cache_path] || generate_temp_cache_path

        if [".yml", ".yaml"].include?(File.extname(path).downcase)
          benchmark_cache_from_manifest(path, cache_path)
        else
          benchmark_cache_file(path, cache_path)
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

      def benchmark_cache_file(path, cache_path)
        say "Express Schema Loading Benchmark with Caching"
        say "--------------------------------"
        say "Schema: #{path}"
        say "Cache: #{cache_path}"
        say "--------------------------------"

        # Benchmark with caching
        results = Expressir::Benchmark.measure_with_cache(path,
                                                          cache_path) do |file|
          Expressir::Express::Parser.from_file(file)
        end

        if results[:repository]
          schema_count = results[:repository].schemas.size
          say "Loaded #{schema_count} schemas"
        else
          say "Failed to load schema"
        end
      end

      def benchmark_cache_from_manifest(manifest_path, cache_path)
        say "Express Schema Loading Benchmark with Caching from Manifest"
        say "--------------------------------"

        # Load schema manifest
        manifest = Expressir::SchemaManifest.from_file(manifest_path)
        schema_files = manifest.schemas.map(&:path)

        say "Manifest File: #{manifest_path}"
        say "Number of schemas in list: #{schema_files.size}"
        say "Cache: #{cache_path}"
        say "--------------------------------"

        # Process each file with caching
        schema_files.each_with_index do |file, index|
          say "Processing file #{index + 1}/#{schema_files.size}: #{file}"

          # Benchmark with caching
          Expressir::Benchmark.measure_with_cache(file, cache_path) do |path|
            Expressir::Express::Parser.from_file(path)
          end

          say "--------------------------------"
        end
      end

      def generate_temp_cache_path
        require "tempfile"
        Tempfile.new(["expressir_cache", ".bin"]).path
      end
    end
  end
end
