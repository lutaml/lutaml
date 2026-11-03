# frozen_string_literal: true

require "bundler/setup"
require "expressir"
require "parsanol"

src = File.read(File.expand_path("../spec/syntax/syntax.exp", __dir__))
begin
  Expressir::Express::Grammar::Parser.cached_parser.parse(src)
  puts "OK"
rescue Parsanol::ParseFailed => e
  puts "FAIL: #{e.message[0, 200]}"
  # find the deepest cited line/char and show the source there
  if e.message =~ /line (\d+) char (\d+)/
    line = Regexp.last_match(1).to_i
    char = Regexp.last_match(2).to_i
    text = src.lines[line - 1].to_s
    puts "line #{line}: #{text.inspect[0, 140]}"
    puts "  #{' ' * [char - 1, 0].max}^"
  end
end
