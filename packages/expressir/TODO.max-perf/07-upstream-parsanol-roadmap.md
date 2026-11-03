# TODO.max-perf/07 — Upstream parsanol roadmap (research 2022–2026)

## Context

The field's fastest grammar engines compile grammars instead of interpreting
them. Mapping to parsanol (all upstream work; expressir only consumes):

| Technique | Precedent | parsanol mapping |
|---|---|---|
| JIT grammar compilation + tag-dispatched structure switching + cross-grammar cache reuse (6x) | XGrammar-2 (arXiv:2601.04426) | BYTE_DISPATCH is conceptually TagDispatch; compile to a dispatch table per atom |
| Grammar → generated code (production precedent) | tree-sitter (precompiled C, incremental reparse), CPython's generated PEG parser | generate Rust from the EXPRESS grammar instead of walking atom structs |
| Skip packrat tables via automata | Pest discussion #1081 | memoization-free automata for the deterministic fragments; keep packrat only where ambiguity needs it |
| SIMD byte classification (GB/s lexing) | simdjson, Lemire's vectorized classification (arXiv:2503.01662) | vectorize keyword/delimiter classification in the lexer tier |
| Incremental re-parse | tree-sitter, gpeg (SLE'21) | re-parse only dirty schema blocks — pairs with expressir's SchemaBlockScanner |

## Work

- [x] Filed parsanol-ruby#59 with the mapping, profile evidence, citations,
      and the Ractor-safe entry point item (the only parallelism option on
      Windows MRI and fork-hostile embedders)
- [x] Consumer unlocks noted: incremental reparse pairs with expressir's
      SchemaBlockScanner; compiled grammar cuts cold-start (~2,300 atoms
      serialized per boot); ractor-safe parse replaces the fork pool

## Acceptance

Upstream issue filed; expressir-side dependencies on each technique noted.

## Status: done

- Upstreamed: parsanol-ruby#59, leptris/yeptris#318, lutaml-model#798; parsanol 1.3.28's backtracking fix adopted.
