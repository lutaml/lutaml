# frozen_string_literal: true

# Tree-diff the DSL lane against the artifact lane for a fixture:
# reports the first path where the two named trees diverge.
#
#   ruby -I <parsanol-lib> tree_diff.rb <file.exp>

$LOAD_PATH.unshift(ARGV[0]) if ARGV[0]

require "bundler/setup"
require "expressir"
require "parsanol"

src = File.read(ARGV[-1])
dsl = Expressir::Express::Grammar::Parser.cached_parser.parse(src)
art = Expressir::Express::Grammar::Parser.parse_artifact(src)

diffs = []
walk = lambda do |a, b, path|
  return if diffs.size >= 8

  if a.is_a?(Parsanol::Slice) || b.is_a?(Parsanol::Slice)
    diffs << "#{path}: #{a.inspect} vs #{b.inspect}" if a.inspect != b.inspect
    return
  end
  return unless a.is_a?(Hash) && b.is_a?(Hash)

  ka = a.keys - [:comments]
  kb = b.keys - [:comments]
  # :comments = the trivia-recording channel (DSL source-preserving
  # mode records whitespace units; the artifact lane does not). The
  # builder never reads it (find_slice skips :spaces; remarks ride the
  # RemarkScanner over source), so it is out of tree-parity scope.
  if ka != kb
    diffs << "#{path}: keys #{ka.inspect} vs #{kb.inspect}"
    return
  end

  a.each_key do |k|
    # Trivia channels, proven builder-inert (no builder reads them;
    # find_slice skips :spaces; remarks ride the RemarkScanner): the
    # DSL records whitespace units, the artifact lane does not.
    next if %i[comments spaces].include?(k)

    va = a[k]
    vb = b[k]
    if va.is_a?(Array) && vb.is_a?(Array)
      if va.size != vb.size
        diffs << "#{path}/#{k}: array size #{va.size} vs #{vb.size}"
        next
      end
      va.each_with_index { |el, i| walk.call(el, vb[i], "#{path}/#{k}[#{i}]") }
    elsif va.is_a?(Hash) && vb.is_a?(Hash)
      walk.call(va, vb, "#{path}/#{k}")
    elsif va.class != vb.class || (va.respond_to?(:to_s) && va.to_s != vb.to_s)
      diffs << "#{path}/#{k}: #{va.inspect[0, 80]} vs #{vb.inspect[0, 80]}"
    end
  end
end
walk.call(dsl, art, "root")

puts diffs.empty? ? "TREES IDENTICAL" : diffs.first(8)
