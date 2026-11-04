# frozen_string_literal: true

# Splices the fragments into express.parg. Idempotent: rebuilds from the
# head (everything before the keyword block). Order: keywords, literals,
# operators, entries (the closing brace rides the entries fragment).
FRAGMENTS = %w[
  keywords.parg.frag
  literals.parg.frag
  operators.parg.frag
  entries.parg.frag
].freeze

g = File.read("express.parg")
head = g.split("# --- keyword terminals")[0]
File.write("express.parg", head + FRAGMENTS.map { |f| File.read(f) }.join)
puts "spliced"
