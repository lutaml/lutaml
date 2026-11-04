#!/usr/bin/env ruby
# frozen_string_literal: true

# SRL Benchmark Script for Expressir
# Compares Parsanol Ruby vs Native performance on full STEPmod Resource Library
# Features: Live progress, emojis, colors, per-schema stats

require "bundler/setup"
require "benchmark"
require "fileutils"

# Force loading of native extension
require "parsanol"
require "parsanol/native"

# Now require expressir
require "expressir"

# Configuration
SRL_PATH = ENV["SRL_PATH"] ||
  "/Users/mulgogi/src/mn/iso-10303/schemas/resources"
ITERATIONS = (ENV["ITERATIONS"] || 1).to_i
TIMEOUT_SECONDS = (ENV["TIMEOUT"] || 30).to_i # Timeout per file

# Check if we're running in an interactive terminal
INTERACTIVE = $stdout.tty?

# ANSI Color codes
module Colors
  RESET = "\e[0m"
  BOLD = "\e[1m"
  DIM = "\e[2m"

  # Foreground colors
  BLACK = "\e[30m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN = "\e[36m"
  WHITE = "\e[37m"

  # Bright foreground colors
  BRIGHT_RED = "\e[91m"
  BRIGHT_GREEN = "\e[92m"
  BRIGHT_YELLOW = "\e[93m"
  BRIGHT_BLUE = "\e[94m"
  BRIGHT_MAGENTA = "\e[95m"
  BRIGHT_CYAN = "\e[96m"
  BRIGHT_WHITE = "\e[97m"

  # Background colors
  BG_RED = "\e[41m"
  BG_GREEN = "\e[42m"
  BG_YELLOW = "\e[43m"
  BG_BLUE = "\e[44m"
  BG_MAGENTA = "\e[45m"
  BG_CYAN = "\e[46m"
end

include Colors

# Terminal utilities
module Terminal
  class << self
    def width
      IO.console.winsize[1]
    rescue StandardError
      80
    end

    def clear_line
      INTERACTIVE ? "\r\e[K" : ""
    end

    def move_to_start
      INTERACTIVE ? "\r" : ""
    end
  end
end

# Progress bar
class ProgressBar
  def initialize(total, width = 30)
    @total = total
    @width = width
    @current = 0
  end

  def render(current, label = "")
    @current = current
    percentage = (@current.to_f / @total * 100).round(1)
    filled = (@width * @current / @total.to_f).round
    empty = @width - filled

    bar = "#{BRIGHT_CYAN}#{'█' * filled}#{DIM}#{'░' * empty}#{RESET}"
    "#{bar} #{BRIGHT_WHITE}#{percentage.to_s.rjust(5)}%#{RESET} #{DIM}#{label}#{RESET}"
  end
end

def find_exp_files
  Dir.glob("#{SRL_PATH}/*/*.exp").reject do |f|
    f.include?("quantities_and_units")
  end
end

# Parse one file in a forked child with a hard wall-clock kill.
# Ruby's Timeout cannot interrupt the native parser (the GVL is held
# for the whole FFI call), so process isolation is the only reliable
# guard against pathological backtracking hangs.
def parse_file_isolated(file, use_native:, timeout: TIMEOUT_SECONDS)
  rd, wr = IO.pipe
  pid = fork do
    rd.close
    t = Time.now
    result = { status: "ok", elapsed: 0.0, error: nil }
    begin
      if use_native
        content = File.read(file)
        Expressir::Express::Parser.from_exp(content, skip_references: true,
                                                     use_native: true)
      else
        Expressir::Express::Parser.from_file(file, skip_references: true,
                                                   use_native: false)
      end
    rescue StandardError => e
      result[:status] = "err"
      result[:error] = "#{e.class}: #{e.message[0..60]}"
    end
    result[:elapsed] = Time.now - t
    data = Marshal.dump(result)
    wr.write([data.bytesize].pack("N"))
    wr.write(data)
    wr.close
    exit!(0)
  end
  wr.close

  deadline = Time.now + timeout
  timed_out = false
  loop do
    done = Process.waitpid(pid, Process::WNOHANG)
    break if done

    if Time.now > deadline
      Process.kill("TERM", pid)
      sleep 1
      begin
        Process.kill("KILL", pid) if Process.waitpid(pid, Process::WNOHANG).nil?
      rescue StandardError
        nil
      end
      timed_out = true
      break
    end
    sleep 0.1
  end

  if timed_out
    rd.close
    { status: "timeout", elapsed: timeout.to_f, error: "Timeout after #{timeout}s" }
  else
    header = rd.read(4)
    payload = header && Marshal.load(rd.read(header.unpack1("N"))) # rubocop:disable Security/MarshalLoad
    rd.close
    payload
  end
end

def count_lines(files)
  files.sum { |f| File.read(f).lines.count }
end

def format_time(seconds)
  if seconds < 60
    "#{seconds.round(2)}s"
  else
    minutes = (seconds / 60).floor
    secs = (seconds % 60).round(1)
    "#{minutes}m #{secs}s"
  end
end

def format_number(num)
  num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def print_header
  puts
  puts "#{BRIGHT_MAGENTA}#{'═' * 60}#{RESET}"
  puts "#{BRIGHT_MAGENTA}║#{RESET}#{BOLD}#{BRIGHT_WHITE}  🚀 EXPRESSIR SRL BENCHMARK 🚀  #{RESET}#{BRIGHT_MAGENTA}║#{RESET}"
  puts "#{BRIGHT_MAGENTA}║#{RESET}#{DIM}  Ruby vs Native Parser Showdown   #{RESET}#{BRIGHT_MAGENTA}║#{RESET}"
  puts "#{BRIGHT_MAGENTA}#{'═' * 60}#{RESET}"
  puts
end

def print_config(files, total_lines)
  puts "#{BRIGHT_CYAN}⚙️  Configuration#{RESET}"
  puts "#{DIM}┌─────────────────────────────────────────────┐#{RESET}"
  puts "#{DIM}│#{RESET} 📁 Files:      #{BRIGHT_WHITE}#{format_number(files.size).rjust(10)}#{RESET}               #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET} 📊 Lines:      #{BRIGHT_WHITE}#{format_number(total_lines).rjust(10)}#{RESET}               #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET} 🔄 Iterations: #{BRIGHT_WHITE}#{ITERATIONS.to_s.rjust(10)}#{RESET}               #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET} 🦀 Native:     #{BRIGHT_WHITE}#{Parsanol::Native.available?.to_s.upcase.rjust(10)}#{RESET}               #{DIM}│#{RESET}"
  puts "#{DIM}└─────────────────────────────────────────────┘#{RESET}"
  puts
end

def print_warmup_start
  print "#{BRIGHT_YELLOW}🔥 Warming up...#{RESET} "
end

def print_warmup_done
  puts "#{BRIGHT_GREEN}✅ Done!#{RESET}"
  puts
end

class ParserBenchmark
  attr_reader :name, :emoji, :color, :results

  def initialize(name:, emoji:, color:, use_native:)
    @name = name
    @emoji = emoji
    @color = color
    @use_native = use_native
    @results = []
  end

  def run(files, _total_lines)
    puts "#{@color}#{@emoji} #{@name}#{@RESET}"
    puts "#{DIM}┌──────────────────────────────────────────────────────────┐#{RESET}"

    progress_bar = ProgressBar.new(files.size, 25)
    iteration_results = { success: 0, failed: 0, errors: [], time: 0,
                          schema_times: [] }
    start_time = Time.now

    files.each_with_index do |file, idx|
      schema_name = File.basename(file, ".exp")
      file_start = Time.now
      schema_lines = File.read(file).lines.count

      result = parse_file_isolated(file, use_native: @use_native)
      result[:elapsed]

      case result[:status]
      when "ok"
        iteration_results[:success] += 1
        status = "#{BRIGHT_GREEN}✓#{RESET}"
      when "timeout"
        iteration_results[:failed] += 1
        iteration_results[:errors] << { file: File.basename(file),
                                        error: result[:error] }
        status = "#{BRIGHT_YELLOW}⏱#{RESET}"
      else
        iteration_results[:failed] += 1
        iteration_results[:errors] << { file: File.basename(file),
                                        error: result[:error] }
        status = "#{BRIGHT_RED}✗#{RESET}"
      end

      elapsed = Time.now - file_start
      iteration_results[:schema_times] << { name: schema_name, time: elapsed,
                                            lines: schema_lines }

      # Live progress update
      if INTERACTIVE
        progress_label = "#{status} #{schema_name[0..20].ljust(21)}"
        print "#{Terminal.clear_line}  #{progress_bar.render(idx + 1,
                                                             progress_label)}"
        $stdout.flush
      elsif ((idx + 1) % 10).zero? || idx.zero?
        # Print progress every 10 files when not interactive
        pct = ((idx + 1).to_f / files.size * 100).round(1)
        puts "  #{progress_bar.render(idx + 1, "#{pct}% complete")}"
        $stdout.flush
      end
    end

    if INTERACTIVE
      puts
    end

    iteration_results[:time] = Time.now - start_time
    @results << iteration_results
    iteration_results
  end

  def print_summary(files, total_lines, result)
    avg_time = result[:time]
    lines_per_sec = (total_lines / avg_time).round(1)
    files_per_sec = (files.size / avg_time).round(2)

    puts "#{DIM}├──────────────────────────────────────────────────────────┤#{RESET}"
    puts "#{DIM}│#{RESET} #{BOLD}Results:#{RESET}"
    puts "#{DIM}│#{RESET}   #{BRIGHT_GREEN}✅ Success:#{RESET}  #{BRIGHT_WHITE}#{result[:success].to_s.rjust(5)}#{RESET} / #{files.size} files"
    puts "#{DIM}│#{RESET}   #{BRIGHT_RED}❌ Failed:#{RESET}   #{BRIGHT_WHITE}#{result[:failed].to_s.rjust(5)}#{RESET} files"
    puts "#{DIM}│#{RESET}   #{BRIGHT_CYAN}⏱️  Time:#{RESET}    #{BRIGHT_WHITE}#{format_time(avg_time).rjust(5)}#{RESET}"
    puts "#{DIM}│#{RESET}   #{BRIGHT_YELLOW}⚡ Speed:#{RESET}   #{BRIGHT_WHITE}#{format_number(lines_per_sec).rjust(5)}#{RESET} lines/sec"

    if result[:failed].positive? && result[:failed] <= 5
      puts "#{DIM}├──────────────────────────────────────────────────────────┤#{RESET}"
      puts "#{DIM}│#{RESET} #{BRIGHT_RED}⚠️  Errors:#{RESET}"
      result[:errors].first(3).each do |err|
        puts "#{DIM}│#{RESET}    #{DIM}• #{err[:file]}: #{err[:error][0..40]}#{RESET}"
      end
    end

    puts "#{DIM}└──────────────────────────────────────────────────────────┘#{RESET}"
    puts

    { avg_time: avg_time, lines_per_sec: lines_per_sec,
      files_per_sec: files_per_sec }
  end

  def print_slowest_schemas(result, count = 5)
    return if result[:schema_times].empty?

    slowest = result[:schema_times].sort_by { |s| -s[:time] }.first(count)

    puts "#{@color}#{@emoji} Slowest Schemas#{@RESET}"
    puts "#{DIM}┌─────────────────────────────────────────────────────┐#{RESET}"
    slowest.each_with_index do |s, i|
      rank = "#{BRIGHT_WHITE}#{(i + 1).to_s.rjust(2)}.#{RESET}"
      name = s[:name][0..25].ljust(26)
      time = "#{BRIGHT_CYAN}#{s[:time].round(1)}s#{RESET}".rjust(8)
      lines = "#{DIM}#{s[:lines]} lines#{RESET}"
      puts "#{DIM}│#{RESET} #{rank} #{name} #{time} #{lines}"
    end
    puts "#{DIM}└─────────────────────────────────────────────────────┘#{RESET}"
    puts
  end
end

def print_comparison(ruby_stats, native_stats, files, total_lines)
  speedup = (ruby_stats[:avg_time] / native_stats[:avg_time]).round(1)
  time_saved = (ruby_stats[:avg_time] - native_stats[:avg_time]).round(2)

  puts "#{BRIGHT_MAGENTA}#{'═' * 60}#{RESET}"
  puts "#{BOLD}#{BRIGHT_WHITE}       📊 PERFORMANCE COMPARISON 📊       #{RESET}"
  puts "#{BRIGHT_MAGENTA}#{'═' * 60}#{RESET}"
  puts

  puts "#{DIM}┌─────────────────────────────────────────────────────┐#{RESET}"
  puts "#{DIM}│#{RESET}#{BOLD}                 HEAD-TO-HEAD                   #{RESET}#{DIM}│#{RESET}"
  puts "#{DIM}├─────────────────────────────────────────────────────┤#{RESET}"
  puts "#{DIM}│#{RESET}                                                     #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}  #{BRIGHT_BLUE}💎 Ruby Parser#{RESET}    #{format_time(ruby_stats[:avg_time]).rjust(10)}               #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}     #{DIM}#{format_number(ruby_stats[:lines_per_sec])} lines/sec#{RESET}                          #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}                                                     #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}  #{BRIGHT_CYAN}🦀 Native Parser#{RESET}   #{format_time(native_stats[:avg_time]).rjust(10)}               #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}     #{DIM}#{format_number(native_stats[:lines_per_sec])} lines/sec#{RESET}                          #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}                                                     #{DIM}│#{RESET}"
  puts "#{DIM}├─────────────────────────────────────────────────────┤#{RESET}"

  if speedup > 1
    puts "#{DIM}│#{RESET}  #{BOLD}#{BRIGHT_GREEN}🏆 WINNER: Native Parser#{RESET}                     #{DIM}│#{RESET}"
    puts "#{DIM}│#{RESET}  #{BRIGHT_YELLOW}⚡ Speedup:#{RESET}     #{BOLD}#{BRIGHT_GREEN}#{speedup}x FASTER#{RESET}                  #{DIM}│#{RESET}"
    puts "#{DIM}│#{RESET}  #{BRIGHT_YELLOW}⏱️  Time Saved:#{RESET}  #{BRIGHT_GREEN}#{format_time(time_saved)} per run#{RESET}             #{DIM}│#{RESET}"
  else
    puts "#{DIM}│#{RESET}  #{BOLD}#{BRIGHT_BLUE}🏆 WINNER: Ruby Parser#{RESET}                       #{DIM}│#{RESET}"
    puts "#{DIM}│#{RESET}  #{BRIGHT_YELLOW}⚡ Speedup:#{RESET}     #{BOLD}#{BRIGHT_BLUE}#{(1 / speedup).round(1)}x FASTER#{RESET}                  #{DIM}│#{RESET}"
  end

  puts "#{DIM}│#{RESET}                                                     #{DIM}│#{RESET}"
  puts "#{DIM}└─────────────────────────────────────────────────────┘#{RESET}"
  puts

  # Summary
  puts "#{DIM}┌─────────────────────────────────────────────────────┐#{RESET}"
  puts "#{DIM}│#{RESET}#{BOLD}                    SUMMARY                        #{RESET}#{DIM}│#{RESET}"
  puts "#{DIM}├─────────────────────────────────────────────────────┤#{RESET}"
  puts "#{DIM}│#{RESET}  📦 #{format_number(files.size)} schemas (#{format_number(total_lines)} lines)         #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}  #{BRIGHT_BLUE}Ruby:#{RESET}   #{format_time(ruby_stats[:avg_time]).rjust(8)}                              #{DIM}│#{RESET}"
  puts "#{DIM}│#{RESET}  #{BRIGHT_CYAN}Native:#{RESET} #{format_time(native_stats[:avg_time]).rjust(8)}                              #{DIM}│#{RESET}"
  puts "#{DIM}└─────────────────────────────────────────────────────┘#{RESET}"
  puts
end

def print_footer
  puts "#{BRIGHT_MAGENTA}#{'═' * 60}#{RESET}"
  puts "#{BOLD}#{BRIGHT_WHITE}         ✨ BENCHMARK COMPLETE ✨          #{RESET}"
  puts "#{BRIGHT_MAGENTA}#{'═' * 60}#{RESET}"
  puts
end

# ==================== MAIN ====================

print_header

# Find all EXPRESS files
files = find_exp_files
total_lines = count_lines(files)

if files.empty?
  puts "#{BRIGHT_RED}❌ ERROR: No EXPRESS files found at #{SRL_PATH}#{RESET}"
  exit 1
end

print_config(files, total_lines)

# Warmup
print_warmup_start
warmup_file = files.first

begin
  Expressir::Express::Parser.from_file(warmup_file, skip_references: true,
                                                    use_native: false)
rescue StandardError => e
  puts "#{BRIGHT_YELLOW}⚠️  Ruby warmup warning: #{e.message[0..40]}#{RESET}"
end

if Parsanol::Native.available?
  begin
    content = File.read(warmup_file)
    Expressir::Express::Parser.from_exp(content, skip_references: true,
                                                 use_native: true)
  rescue StandardError => e
    puts "#{BRIGHT_YELLOW}⚠️  Native warmup warning: #{e.message[0..40]}#{RESET}"
  end
end

print_warmup_done

# Ruby Benchmark
ruby_benchmark = ParserBenchmark.new(
  name: "Ruby Parser",
  emoji: "💎",
  color: BRIGHT_BLUE,
  use_native: false,
)

ruby_result = ruby_benchmark.run(files, total_lines)
ruby_stats = ruby_benchmark.print_summary(files, total_lines, ruby_result)
ruby_benchmark.print_slowest_schemas(ruby_result)

# Native Benchmark (if available)
if Parsanol::Native.available?
  native_benchmark = ParserBenchmark.new(
    name: "Native Parser (Rust)",
    emoji: "🦀",
    color: BRIGHT_CYAN,
    use_native: true,
  )

  native_result = native_benchmark.run(files, total_lines)
  native_stats = native_benchmark.print_summary(files, total_lines,
                                                native_result)
  native_benchmark.print_slowest_schemas(native_result)

  # Print comparison
  print_comparison(ruby_stats, native_stats, files, total_lines)
else
  puts "#{BRIGHT_YELLOW}⚠️  Native parser not available. Run `rake compile` in parsanol-ruby to build.#{RESET}"
  puts
end

print_footer
