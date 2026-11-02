# frozen_string_literal: true

# STEP 1 (issue #578): serialize the LIVE DSL atom tree to PARG text at
# edition v2. The native serialize_grammar dump is a flattened VM
# program — it CSE-mangles alias rules and drops leading lookaheads —
# so this walks the real atoms from the cached parser instead: rule
# bodies from Parser#send(name), Lookahead#bound_parslet for guards,
# Named#parslet/#name for captures, Entity#rule_name for references.

out_path = ARGV[0] || File.join(__dir__, "express-grammar.parg")

require "bundler/setup"
require "expressir"

require_relative File.join(__dir__, "generate-terminals.rb")

# generate-terminals.rb prints its generated PARG text on load; silence
# that noise — the serializer only needs its KEYWORDS constant.
def puts(*); end

parser = Expressir::Express::Grammar::Parser.cached_parser

SKIP_RULE = "space"
ATOMIC_RULES = %w[simpleId digits spaces space embeddedRemark tailRemark].freeze
RULE_NAMES = File.read(File.join(__dir__, "RULE-INVENTORY.txt"))
                 .scan(/^\[ \] (\w+)$/).flatten + ["syntax"] +
                KEYWORDS.map { |kw| "t#{kw}" }

REJECTED = Hash.new(0)

# The DSL skip configuration: skip(:trivia, whitespace: :space, exempt:
# [simpleId digits spaces space embeddedRemark tailRemark]) — the trivia
# channel is PURE WHITESPACE (remarks are product data, matched
# explicitly by grammar bodies via `space`/`spaces`); `capture: space`
# with a whitespace-only rule is the PARG form of the DSL's
# source-preserving mode; the exempt list rides the `atomic` keyword.
SKIP_DECL = "skip = trivia capture: space"

class AtomRenderer
  def initialize(rejected, alt_rules)
    @rejected = rejected
    @alt_rules = alt_rules
  end

  def render(atom)
    case atom
    when Parsanol::Atoms::Str then literal(atom.str)
    when Parsanol::Atoms::Re then lower_re(atom.re.source)
    when Parsanol::Atoms::Entity then atom.rule_name.to_s
    when Parsanol::Atoms::Named then "(#{render(atom.parslet)}) as #{atom.name}"
    when Parsanol::Atoms::Sequence
      atom.parslets.map { |c| child_seq(c) }.join(" ")
    when Parsanol::Atoms::Alternative
      atom.alternatives.map { |c| child_alt(c) }.join(" / ")
    when Parsanol::Atoms::Repetition
      mx = atom.max
      "#{atom.min}#{mx ? "*#{mx}" : "*"} #{child_rep(atom.parslet)}"
    when Parsanol::Atoms::Lookahead
      inner = render(atom.bound_parslet)
      atom.positive ? "&(#{inner})" : "!(#{inner})"
    else
      @rejected["atom #{atom.class}"] += 1
      "<REJECTED>"
    end
  end

  private

  def child_seq(atom)
    raw = render(atom)
    atom.is_a?(Parsanol::Atoms::Alternative) ? "(#{raw})" : raw
  end

  def child_alt(atom)
    raw = render(atom)
    atom.is_a?(Parsanol::Atoms::Sequence) && !raw.start_with?("(") ? "(#{raw})" : raw
  end

  def child_rep(atom)
    raw = render(atom)
    if atom.is_a?(Parsanol::Atoms::Sequence)
      "(#{raw})"
    elsif atom.is_a?(Parsanol::Atoms::Alternative)
      "(#{raw})"
    else
      raw
    end
  end

  # Lower a single-character-class regex to PARG %x alternatives.
  def lower_re(pattern)
    case pattern
    when "." then "%x01-10FFFF"
    # the one quantified concat in the grammar (identifier head+tail)
    when "[a-zA-Z_][a-zA-Z0-9_]*"
      "((%x41-5A / %x61-7A / %x5F) 0* (%x30-39 / %x41-5A / %x61-7A / %x5F))"
    else
      m = pattern.match(/\A\[(.*)\]\z/m) or return reject_re(pattern)
      body = m[1]
      negated = body.sub!(/\A\^/, "")
      pairs = [] # [lo, hi] numeric pairs
      i = 0
      while i < body.length
        ch = body[i]
        if ch == "\\" && i + 1 < body.length
          nxt = body[i + 1]
          codes = { "r" => 0x0D, "n" => 0x0A, "t" => 0x09, "f" => 0x0C }
          if (code = codes[nxt])
            pairs << [code, code]
          elsif nxt == "s"
            pairs.concat([[0x20, 0x20], [0x09, 0x09], [0x0A, 0x0A],
                          [0x0D, 0x0D], [0x0C, 0x0C]])
          else
            return reject_re(pattern)
          end
          i += 2
        elsif i + 2 < body.length && body[i + 1] == "-"
          return reject_re(pattern) if ch == "\\"

          pairs << [ch.ord, body[i + 2].ord]
          i += 3
        else
          pairs << [ch.ord, ch.ord]
          i += 1
        end
      end
      if negated
        # numeric complement over [0x01, 0x10FFFF]
        comp = []
        lo = 1
        pairs.sort.each do |plo, phi|
          next if phi < lo

          comp << [lo, plo - 1] if plo > lo
          lo = [lo, phi + 1].max
        end
        comp << [lo, 0x10FFFF] if lo <= 0x10FFFF
        render_ranges(comp)
      else
        grouped = pairs.size > 1
        text = render_ranges(pairs)
        grouped ? "(#{text})" : text
      end
    end
  end

  def render_ranges(ranges)
    ranges.map do |lo, hi|
      lo == hi ? "%x#{format('%02X', lo)}" : "%x#{format('%02X', lo)}-#{format('%02X', hi)}"
    end.join(" / ")
  end

  def reject_re(pattern)
    @rejected["Re #{pattern.inspect}"] += 1
    "<UNLOWERABLE-RE>"
  end

  def literal(text)
    text.chars.map do |c|
      case c.ord
      when 0x22 then "%x22"
      when 0x5C then "%x5C"
      when 0x2F then "%x2F"
      else
        c.match?(/[[:print:]]/) && !c.match?(/[[:space:]]/) ? "\"#{c}\"" : "%x#{format('%02X', c.ord)}"
      end
    end.join(" ")
  end
end

# -- build the rule table: name -> body atom --
# rule(:x) returns a lazy Entity holding @body (the DSL block); the body
# materializes by instance_exec on the parser, exactly as parsanol does
# at parse time.
rules = {}
RULE_NAMES.uniq.each do |name|
  atom = parser.public_send(name) rescue next
  if atom.is_a?(Parsanol::Atoms::Entity) && atom.rule_name.to_s == name
    body = atom.instance_variable_get(:@cached_atom)
    body ||= parser.instance_exec(&(atom.instance_variable_get(:@body)))
    rules[name] = body || atom
  else
    rules[name] = atom
  end
end

alt_rules = rules.select { |_, body| body.is_a?(Parsanol::Atoms::Alternative) }.keys
warn "rules: #{rules.size}/#{RULE_NAMES.uniq.size}"

# -- emit --
out = []
out << "grammar ExpressSyntax version \"0.1.0\" edition 2 {"
out << "  # The DSL's trivia channel (match[\" \\r\\n\\t\\f\"].repeat(1)) is"
out << "  # emitted below from the live rule; remarks stay product data."

renderer = AtomRenderer.new(REJECTED, alt_rules)
rules.sort_by { |name, _| name }.each do |name, body|
  decl = ATOMIC_RULES.include?(name) ? "atomic #{name} =" : "#{name} ="
  out << "  #{decl} #{renderer.render(body)}"
end

out << "  #{SKIP_DECL}"

out << "  entry syntax: syntax"
out << "}"

File.write(out_path, out.join("\n") + "\n")
warn "wrote #{out_path} (#{out.size} lines)"
unless REJECTED.empty?
  warn "REJECTED (#{REJECTED.values.sum}):"
  REJECTED.first(10).each { |k, n| warn "  #{n}x #{k}" }
end
exit REJECTED.empty? ? 0 : 1
