#!/usr/bin/env ruby
# frozen_string_literal: true

# SRL Benchmark Script for Expressir - Native Parser Only
# Tests Rust native parser performance on full STEPmod Resource Library

require "bundler/setup"
require "benchmark"
require "fileutils"

# Force loading of native extension first
require "parsanol"
require "parsanol/native"

# Now require expressir
require "expressir"

# Configuration
SRL_PATH = "/Users/mulgogi/src/mn/iso-10303/schemas/resources"

def find_exp_files
  Dir.glob("#{SRL_PATH}/*/*.exp")
end

def count_lines(files)
  files.sum { |f| File.read(f).lines.count }
end

puts "=" * 70
puts "EXPRESSIR SRL BENCHMARK: Native Parser (Rust)"
puts "=" * 70
puts

# Check native availability
native_available = Parsanol::Native.available?
puts "Native parser available: #{native_available ? 'YES' : 'NO'}"
puts

if !native_available
  puts "Native parser not available. Run `rake compile` in parsanol-ruby."
  exit 1
end

# Find all EXPRESS files
files = find_exp_files
total_lines = count_lines(files)

puts "Files to parse: #{files.size}"
puts "Total lines of code: #{total_lines}"
puts

if files.empty?
  puts "ERROR: No EXPRESS files found at #{SRL_PATH}"
  exit 1
end

# Warmup - parse first file to ensure everything is loaded
puts "Warming up..."
warmup_file = files.first
begin
  content = File.read(warmup_file)
  Expressir::Express::Parser.from_exp(content, skip_references: true,
                                               use_native: true)
  puts "Warmup complete."
rescue StandardError => e
  puts "Warning: Warmup failed: #{e.message}"
  puts e.backtrace.first(5)
end
puts

# Run Native benchmark
puts "-" * 70
puts "NATIVE PARSER BENCHMARK"
puts "-" * 70

results = { success: 0, failed: 0, errors: [], total_time: 0 }
file_times = []

time = Benchmark.realtime do
  files.each_with_index do |file, idx|
    file_start = Time.now
    begin
      content = File.read(file)
      Expressir::Express::Parser.from_exp(content, skip_references: true,
                                                   use_native: true)
      results[:success] += 1
      file_time = Time.now - file_start
      file_times << { file: File.basename(file), time: file_time,
                      lines: content.lines.count }

      # Progress every 10 files
      if ((idx + 1) % 10).zero?
        print "."
        $stdout.flush
      end
    rescue StandardError => e
      results[:failed] += 1
      results[:errors] << { file: File.basename(file),
                            error: e.message[0..100] }
    end
  end
end
puts

results[:total_time] = time

# Calculate stats
lines_per_sec = (total_lines / results[:total_time]).round(1)
files_per_sec = (files.size / results[:total_time]).round(2)

puts
puts "Native Parser Results:"
puts "  Success: #{results[:success]}/#{files.size} files"
puts "  Failed:  #{results[:failed]} files"
puts "  Time:    #{results[:total_time].round(2)}s"
puts "  Speed:   #{lines_per_sec} lines/sec"
puts "  Speed:   #{files_per_sec} files/sec"

if results[:failed].positive?
  puts
  puts "Errors (first 10):"
  results[:errors].first(10).each do |err|
    puts "  - #{err[:file]}: #{err[:error]}"
  end
end

# Show top 5 slowest files
puts
puts "Top 5 slowest files:"
sorted = file_times.sort_by { |f| -f[:time] }.first(5)
sorted.each do |f|
  puts "  #{f[:file]}: #{f[:time].round(2)}s (#{f[:lines]} lines)"
end

# Show top 5 fastest files
puts
puts "Top 5 fastest files:"
sorted = file_times.sort_by { |f| f[:time] }.first(5)
sorted.each do |f|
  puts "  #{f[:file]}: #{f[:time].round(3)}s (#{f[:lines]} lines)"
end

puts
puts "=" * 70
puts "BENCHMARK COMPLETE"
puts "=" * 70
