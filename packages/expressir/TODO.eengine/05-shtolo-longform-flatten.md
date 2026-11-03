# 05 — SHTOLO longform flatten (Annex G)

TODO.parity-ee 05. Convert the STEPmod multi-schema web into ONE
ISO 10303-11:1994 longform schema: no interfaces, visibility
preserved as rules, no name clashes, unreachable declarations pruned.

Sources: `ag-single-schema.adoc` (rule ids), eeng run-op (:flat) +
print-flatten + wo-flat.lisp (373 lines; eeng keeps structure and
lowercases — the standard wins on divergence), add/remove-declaration
and cleanup-interface lisps.

Builds on 01 (visibility), 03 (closures), 04 (rule audit).

## Status: done

- `Expressir::Express::Shtolo#flatten` emits the single longform
  schema: interface closure copied as local declarations, ORIGINAL
  names kept with references rewritten, G.NM.1 clash munging computed
  over the whole closure first.
