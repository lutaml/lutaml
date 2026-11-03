module Expressir
  module Benchmark
    require "benchmark"
    require "json"
    require "csv"

    class << self
      # Measures the execution time of schema loading and optionally reports it
      # @param file [String] File being processed
      # @param options [Hash] Options for benchmarking
      # @return The result of the block
      def measure_file(file)
        return yield unless Expressir.configuration.benchmark_enabled?

        if Expressir.configuration.benchmark_ips?
          require "benchmark/ips"

          result = nil
          ::Benchmark.ips do |x|
            x.config(time: Expressir.configuration.benchmark_iterations,
                     warmup: Expressir.configuration.benchmark_warmup)

            x.report("Loading #{file}") do
              result = yield
            end

            if Expressir.configuration.benchmark_save?
              x.save! "expressir_benchmark_#{File.basename(file)}"
            end
          end

          # Calculate objects per second
          if result.is_a?(Model::Repository)
            objects_per_second = calculate_objects_per_second(result)
            puts "Objects per second: #{objects_per_second}" if Expressir.configuration.benchmark_verbose?
          end

        else
          # Standard benchmarking
          result = nil
          time = ::Benchmark.measure do
            result = yield
          end

          if result.is_a?(Model::Repository)
            objects_per_second = calculate_objects_per_second(result, time.real)
            output_benchmark_result(file, time.real, objects_per_second)
          else
            output_benchmark_result(file, time.real)
          end

        end
        result
      end

      # Benchmarks file collection processing
      # @param files [Array<String>] List of files to process
      # @return [Array] Results from processing files
      def measure_collection(files)
        unless Expressir.configuration.benchmark_enabled?
          # Process each file individually even when benchmarking is disabled
          results = []
          files.each do |file|
            file_results = yield(file)
            results.concat(Array(file_results))
          end
          return results
        end

        results = []
        total_time = ::Benchmark.measure do
          files.each_with_index do |file, i|
            if Expressir.configuration.benchmark_verbose?
              puts "#{i + 1}/#{files.length} Processing #{file}"
            end

            file_results = measure_file(file) do
              yield(file)
            end

            results.concat(Array(file_results))
          end
        end

        output_collection_result(files.length, total_time.real, results)
        results
      end

      # Measures reference resolution
      # @return The result of the block
      def measure_references
        return yield unless Expressir.configuration.benchmark_enabled?

        if Expressir.configuration.benchmark_ips?
          require "benchmark/ips"

          result = nil
          ::Benchmark.ips do |x|
            x.config(time: Expressir.configuration.benchmark_iterations,
                     warmup: Expressir.configuration.benchmark_warmup)

            x.report("Reference resolution") do
              result = yield
            end
          end

        else
          result = nil
          time = ::Benchmark.measure do
            result = yield
          end

          output_benchmark_result("Reference resolution", time.real)
        end
        result
      end

      # Benchmark with caching
      # @param path [String] Path to the file
      # @param cache_path [String] Path for the cache file
      # @return [Hash] Results with timing information
      def measure_with_cache(path, cache_path = nil)
        return yield(path) unless Expressir.configuration.benchmark_enabled?

        require "tempfile"
        temp_file = nil

        unless cache_path
          temp_file = Tempfile.new(["expressir_cache", ".bin"])
          cache_path = temp_file.path
        end

        results = {}

        # Measure parsing time
        parsing_time = ::Benchmark.measure do
          results[:repository] = yield(path)
        end
        results[:parsing_time] = parsing_time.real

        # Measure cache writing time
        cache_write_time = ::Benchmark.measure do
          Expressir::Express::Cache.to_file(cache_path, results[:repository])
        end
        results[:cache_write_time] = cache_write_time.real

        # Measure cache reading time
        cache_read_time = ::Benchmark.measure do
          results[:cached_repository] =
            Expressir::Express::Cache.from_file(cache_path)
        end
        results[:cache_read_time] = cache_read_time.real

        # Output results
        if Expressir.configuration.benchmark_verbose?
          puts "Parsing time:      #{results[:parsing_time].round(4)}s"
          puts "Cache write time:  #{results[:cache_write_time].round(4)}s"
          puts "Cache read time:   #{results[:cache_read_time].round(4)}s"

          if results[:repository].is_a?(Model::Repository)
            objects = count_objects(results[:repository])
            puts "Total objects:     #{objects}"
            puts "Objects per second (parsing): #{(objects / results[:parsing_time]).round(2)}"
            puts "Objects per second (reading): #{(objects / results[:cache_read_time]).round(2)}"
          end
        end

        # Clean up temp file if we created one
        if temp_file
          temp_file.close
          temp_file.unlink
        end

        results
      end

      private

      # Calculate objects per second
      # @param repository [Object] The repository object
      # @param time [Float] The time taken in seconds
      # @return [Float] Objects per second
      def calculate_objects_per_second(repository, time = 1.0)
        objects = count_objects(repository)
        (objects / time).round(2)
      end

      # Count objects in a repository
      # @param repository [Object] The repository object
      # @return [Integer] Number of objects
      def count_objects(repository)
        return 0 unless repository.is_a?(Model::Repository)

        count = repository.schemas.size

        repository.schemas.each do |schema|
          count += schema.entities.size if schema.entities
          count += schema.types.size if schema.types
          count += schema.functions.size if schema.functions
          count += schema.rules.size if schema.rules
          count += schema.procedures.size if schema.procedures
          count += schema.constants.size if schema.constants

          # Count attributes in entities
          schema.entities&.each do |entity|
            # Count explicit attributes
            if entity.attributes
              count += entity.attributes.size
            end

            # Count inheritance relationships
            count += 1 if entity.subtype_of
          end
        end

        count
      end

      # Output benchmark result in the appropriate format
      # @param label [String] Label for the benchmark
      # @param time [Float] Time in seconds
      # @param objects_per_second [Float, nil] Objects per second metric (optional)
      def output_benchmark_result(label, time, objects_per_second = nil)
        time_rounded = time.round(4)

        case Expressir.configuration.benchmark_format
        when "json"
          result = {
            label: label,
            time_seconds: time_rounded,
          }
          result[:objects_per_second] = objects_per_second if objects_per_second
          puts JSON.generate(result)
        when "csv"
          headers = ["Label", "Time (s)"]
          headers << "Objects/s" if objects_per_second

          values = [label, time_rounded]
          values << objects_per_second if objects_per_second

          puts headers.join(",")
          puts values.join(",")
        else
          # Default format
          message = "#{label}: #{time_rounded}s"
          message += " (#{objects_per_second} objects/s)" if objects_per_second
          puts message if Expressir.configuration.benchmark_verbose?
        end
      end

      # Output collection benchmark result
      # @param count [Integer] Number of files processed
      # @param total_time [Float] Total time in seconds
      # @param results [Array] Array of results
      def output_collection_result(count, total_time, results)
        avg_time = total_time / count

        # Get total object count if possible
        total_objects = 0
        schema_count = 0

        # Try to count total objects and schemas
        results.each do |result|
          if result.is_a?(Model::Repository)
            schema_count += result.schemas.size
            total_objects += count_objects(result)
          elsif result.is_a?(Array)
            result.each do |r|
              if r.is_a?(Model::Declarations::Schema)
                schema_count += 1
                total_objects += 1 # Count the schema itself
              end
            end
          end
        end

        objects_per_second = (total_objects / total_time).round(2)

        case Expressir.configuration.benchmark_format
        when "json"
          result = {
            files_processed: count,
            schemas_loaded: schema_count,
            total_objects: total_objects,
            total_time_seconds: total_time.round(4),
            average_time_seconds: avg_time.round(4),
            objects_per_second: objects_per_second,
          }
          puts JSON.generate(result)
        when "csv"
          headers = ["Files", "Schemas", "Objects", "Total Time (s)",
                     "Avg Time (s)", "Objects/s"]
          values = [count, schema_count, total_objects, total_time.round(4),
                    avg_time.round(4), objects_per_second]

          puts headers.join(",")
          puts values.join(",")
        else
          # Default format
          if Expressir.configuration.benchmark_verbose?
            puts "\nProcessed #{count} files in #{total_time.round(4)}s"
            puts "Loaded #{schema_count} schemas containing #{total_objects} objects"
            puts "Average time per file: #{avg_time.round(4)}s"
            puts "Performance: #{objects_per_second} objects/s"
          end
        end
      end
    end
  end
end
