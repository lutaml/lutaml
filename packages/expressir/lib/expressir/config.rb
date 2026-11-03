module Expressir
  module Config
    def configure
      if block_given?
        yield configuration
      end
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  class Configuration
    attr_accessor :logs, :benchmark_enabled, :benchmark_ips, :benchmark_verbose,
                  :benchmark_save, :benchmark_iterations, :benchmark_warmup, :benchmark_parallel,
                  :benchmark_format

    def initialize
      @logs = %i(error)
      # Enable benchmarking via environment variable
      @benchmark_enabled = ENV["EXPRESSIR_BENCHMARK"] == "true"
      # Use benchmark-ips for detailed statistics
      @benchmark_ips = ENV["EXPRESSIR_BENCHMARK_IPS"] == "true"
      # Show verbose output for benchmarking
      @benchmark_verbose = ENV["EXPRESSIR_BENCHMARK_VERBOSE"] == "true"
      # Save benchmark results to file
      @benchmark_save = ENV["EXPRESSIR_BENCHMARK_SAVE"] == "true"
      # Number of iterations for benchmark-ips
      @benchmark_iterations = (ENV["EXPRESSIR_BENCHMARK_ITERATIONS"] || "3").to_i
      # Warmup time for benchmark-ips in seconds
      @benchmark_warmup = (ENV["EXPRESSIR_BENCHMARK_WARMUP"] || "1").to_i
      # Enable parallel processing (for future implementation)
      @benchmark_parallel = ENV["EXPRESSIR_BENCHMARK_PARALLEL"] == "true"
      # Output format for benchmark results (default, json, csv)
      @benchmark_format = ENV["EXPRESSIR_BENCHMARK_FORMAT"] || "default"
    end

    # Helper methods for checking benchmark settings
    def benchmark_enabled?
      @benchmark_enabled
    end

    def benchmark_ips?
      @benchmark_enabled && @benchmark_ips
    end

    def benchmark_verbose?
      @benchmark_enabled && @benchmark_verbose
    end

    def benchmark_save?
      @benchmark_enabled && @benchmark_save
    end

    def benchmark_parallel?
      @benchmark_enabled && @benchmark_parallel
    end
  end
end
