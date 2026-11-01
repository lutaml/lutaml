# frozen_string_literal: true

# Splices the generated keyword fragment + the literal batch into
# express.parg, before the entry declarations. Idempotent: rebuilds the
# file from its head (everything before the keyword block).
g = File.read("express.parg")
head = g.split("# --- keyword terminals")[0]
tail = g[g.index("  entry tSCHEMA:")..]
File.write(
  "express.parg",
  head + File.read("keywords.parg.frag") + "\n" +
          File.read("literals.parg.frag") + "\n" + tail,
)
puts "spliced"
