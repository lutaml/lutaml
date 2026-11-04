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
ATOMIC_RULES = %w[simpleId unguardedId digits spaces space embeddedRemark tailRemark].freeze
RULE_NAMES = File.read(File.join(__dir__, "RULE-INVENTORY.txt"))
  .scan(/^\[ \] (\w+)$/).flatten + ["syntax"] + ["unguardedId"] +
  KEYWORDS.map { |kw| "t#{kw}" }

REJECTED = Hash.new(0)

# The DSL skip configuration: skip(:trivia, whitespace: :space, exempt:
# [simpleId digits spaces space embeddedRemark tailRemark]) — the trivia
# channel is PURE WHITESPACE (remarks are product data, matched
# explicitly by grammar bodies via `space`/`spaces`); the exempt list
# rides the `atomic` keyword. No `capture:` clause: the DSL's trivia
# recording is builder-inert (find_slice skips :spaces, remarks ride
# the RemarkScanner), and parsanol 1.3.123's TriviaCapture#record
# crashes on this grammar (`lstrip` for nil) — plain Trivia keeps the
# artifact lane on the backtracking, capture-free wrapper instead.
SKIP_DECL = "skip = express_remarks.trivia"

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
      inner = child_rep(atom.parslet)
      # PARG binds `as name` to the whole repetition, so an inline
      # capture would hoist outside it (artifacts yield {item: [...]},
      # never the DSL's per-iteration [{item: ...}, ...]). The extra
      # paren layer keeps the capture inside the repetition body.
      inner = "(#{inner})" if atom.parslet.is_a?(Parsanol::Atoms::Named)
      if atom.min.zero? && mx == 1
        # the DSL's .maybe: PARG's bracket-optional compiles to the
        # :maybe tag (named flatten unwraps -> flat trees); a 0*1
        # repetition compiles to :repetition (arrays even when named),
        # which segments the tree exactly like the DSL never would
        "[ #{inner} ]"
      else
        "#{atom.min}#{mx ? "*#{mx}" : '*'} #{inner}"
      end
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
    if atom.is_a?(Parsanol::Atoms::Sequence) || atom.is_a?(Parsanol::Atoms::Alternative)
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
      negated = body.delete_prefix!("^")
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
            pairs.push([0x20, 0x20], [0x09, 0x09], [0x0A, 0x0A],
                       [0x0D, 0x0D], [0x0C, 0x0C])
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
  atom = begin
    parser.public_send(name)
  rescue StandardError
    next
  end
  if atom.is_a?(Parsanol::Atoms::Entity) && atom.rule_name.to_s == name
    body = atom.instance_variable_get(:@cached_atom)
    body ||= parser.instance_exec(&atom.instance_variable_get(:@body))
    rules[name] = body || atom
  else
    rules[name] = atom
  end
end

alt_rules = rules.select { |_, body| body.is_a?(Parsanol::Atoms::Alternative) }.keys
warn "rules: #{rules.size}/#{RULE_NAMES.uniq.size}"

# -- component split (issue: maintainable multi-file grammar) --
# The leaf vocabularies live in their own files, composed by the main
# grammar with top-level `use` declarations. Cross-component rule
# references render namespaced (`express_keywords.tABS`); captures
# keep their own names (the import prefix never touches `as`).
COMPONENTS = {
  "express_keywords" => ->(name) { name.start_with?("t") && name.match?(/\At[A-Z]/) },
  "express_operators" => ->(name) {
    %w[addLikeOp andOp binaryTypeOp? bitwiseOp? compoundOp? divOp? exponentOp?
       infixOp? logicalOp? modOp? multiplicationLikeOp orOp plusLikeOp
       relOp unaryOp xorOp? op_colon op_colon_equal op_comma op_dot op_equal
       op_ge op_gt op_le op_lt op_minus op_not_equal op_plus op_star op_slash
       op_delim op_delim2 op_leftparen op_rightparen op_decl
       op_asterisk op_colon_equals_colon op_colon_less_greater_colon
       op_double_pipe op_equals op_greater_equal op_greater_than
       op_less_equal op_less_greater op_less_than].include?(name)
  },
  "express_remarks" => ->(name) {
    %w[embeddedRemark tailRemark space spaces trivia].include?(name)
  },
  # Pure lexical literals: identifiers, numbers, strings. The TYPE
  # grammar rules (simpleTypes family) stay in the main file — they are
  # syntax, not vocabulary, and would drag expression rules into this
  # component.
  "express_literals" => ->(name) {
    %w[simpleId unguardedId digits simpleStringLiteral
       anyKeyword digit].include?(name)
  },
}.freeze

def component_of(name, components, _rules)
  components.each do |component, matches|
    return component if matches.call(name)
  end
  nil
end

def collect_rule_refs(atom, out) # rubocop:disable Metrics/MethodLength -- a uniform tree walker
  case atom
  when Parsanol::Atoms::Entity then out << atom.rule_name.to_s
  when Parsanol::Atoms::Named, Parsanol::Atoms::Repetition
    collect_rule_refs(atom.parslet, out)
  when Parsanol::Atoms::Sequence then atom.parslets.each { |c| collect_rule_refs(c, out) }
  when Parsanol::Atoms::Alternative then atom.alternatives.each { |c| collect_rule_refs(c, out) }
  when Parsanol::Atoms::Lookahead then collect_rule_refs(atom.bound_parslet, out)
  end
end

# Assign every rule to its component (nil = the main grammar).
rule_component = {}
rules.each_key do |name|
  rule_component[name] = component_of(name, COMPONENTS, rules)
end

# Qualification happens in the Entity case: the component-aware
# renderer prefixes cross-component references.
qualified_renderer = Class.new(AtomRenderer) do
  attr_accessor :current_component, :rule_component

  def render(atom)
    if atom.is_a?(Parsanol::Atoms::Entity)
      name = atom.rule_name.to_s
      target = @rule_component[name]
      if target && target != @current_component
        return "#{target}.#{name}"
      end

      return name
    end
    super
  end
end

emit_component = lambda do |component, names|
  r = qualified_renderer.new(REJECTED, alt_rules)
  r.current_component = component
  r.rule_component = rule_component
  body = []
  names.sort.each do |name|
    atom = rules[name]
    decl = ATOMIC_RULES.include?(name) ? "atomic #{name} =" : "#{name} ="
    body << "  #{decl} #{r.render(atom)}"
  end
  body
end

main_names = rules.keys.select { |name| rule_component[name].nil? }
main_refs = {}
main_names.each do |name|
  refs = []
  collect_rule_refs(rules[name], refs)
  main_refs[name] = refs
end

require "fileutils"
out_dir = File.dirname(out_path)
FileUtils.mkdir_p(out_dir)

# The leaf components: plain grammar blocks (the import prefixes their
# rules on merge).
COMPONENTS.each_key do |component|
  names = rules.keys.select { |name| rule_component[name] == component }
  next if names.empty?

  component_out = []
  component_out << "grammar Express#{component.split('_')[1].capitalize} version \"0.1.0\" edition 2 {"
  component_out.concat(emit_component.call(component, names))
  component_out << "}"
  path = File.join(out_dir, "#{component}.parg")
  File.write(path, "#{component_out.join("\n")}\n")
  warn "wrote #{path} (#{component_out.size} rules)"
end

# The main grammar: top-level `use` the components (the parsers take
# use declarations before the grammar header), then the structural
# rules with qualified cross-component references.
main_out = []
main_out << "# The structural grammar proper. The leaf vocabularies compose"
main_out << "# via top-level use declarations:"
COMPONENTS.each_key { |component| main_out << "use #{component}" }
main_out << ""
main_out << "grammar ExpressSyntax version \"0.1.0\" edition 2 {"
main_out << "  # The DSL's trivia channel (match[\" \\r\\n\\t\\f\"].repeat(1)) is"
main_out << "  # emitted below from the live rule; remarks stay product data."

r = qualified_renderer.new(REJECTED, alt_rules)
r.current_component = nil
r.rule_component = rule_component
main_names.sort.each do |name|
  atom = rules[name]
  decl = ATOMIC_RULES.include?(name) ? "atomic #{name} =" : "#{name} ="
  main_out << "  #{decl} #{r.render(atom)}"
end

main_out << "  #{SKIP_DECL}"

main_out << "  entry syntax: syntax"
main_out << "}"

File.write(out_path, "#{main_out.join("\n")}\n")
warn "wrote #{out_path} (#{main_out.size} rules)"
unless REJECTED.empty?
  warn "REJECTED (#{REJECTED.values.sum}):"
  REJECTED.first(10).each { |k, n| warn "  #{n}x #{k}" }
end
exit REJECTED.empty? ? 0 : 1
