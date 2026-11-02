# DSL → PARG edition-2 migration conventions

The authoritative edition-2 authoring reference is pubid's own grammar
fleet (pubid-grammar/grammars/*.parg) — working `edition 2` files with
the migration idioms documented in their headers. This file pins the
expressir-specific mapping and the parity-critical surfaces.

## Header

```
grammar ExpressSyntax version "0.1.0" edition 2 {
```

## DSL → PARG mapping (verified against parsanol 1.3.120's frontend)

| DSL | PARG |
|---|---|
| `str("x")` | `"x"` |
| `match[/re/]` (char class) | `%xNN-NN` / `%xNN` classes, or literals |
| `a >> b` | juxtaposition: `a b` |
| `a \| b` | `a / b` (ordered choice) |
| `.maybe` | `[a]` |
| `.repeat(1)` / `.repeat` | `1*a` / `*a` |
| `.repeat(m, n)` | `m*n a` |
| `.as(:name)` | `(...) as name` |
| `rule(:x)` (capturing body) | `x = { ... }` brace rule |
| `rule(:x) { simple }` | `x = ...` |
| `skip(:trivia, whitespace: :space, exempt: [...])` | `skip = trivia capture: space` + `atomic <name> = ...` per exempt rule |
| lookahead/behind | `!a` / ¬(behind) — PARG rejects some constructs NAMING them |

## Edition-2 capture discipline (from pubid's fleet, cen_cenelec.parg header)

> Every reference inside a captured body is inlined to raw terms (a rule
> reference materializes as a named node in the edition-2 tree, so only a
> raw capture binds a scalar span); references to rules that themselves
> capture float their captures unchanged. Repetition wrappers keep the
> v1 tree shape and the bindings name the scalar leaves.

Consequence for the translation: a `.as` on a rule REFERENCE does not
bind a span in v2 — either inline the referenced body or bind the leaf
literals directly. The corpus parity loop (Step 1 of issue #578) is the
referee for every one of these decisions.

## Parity-critical surfaces (do not translate mechanically)

1. **Trivia injection + exemptions**: the DSL's `skip(:trivia, exempt:
   %i[simpleId digits spaces space embeddedRemark tailRemark])` encodes
   parsanol-ruby#195's token-boundary semantics — PARG's `atomic`
   declarations must reproduce the exact exemption set, or multi-token
   rules glue ("RULE r FOR" → one simpleId).
2. **Remarks are product data**: tailRemark/embeddedRemark manage their
   own trivia end to end; RemarkScanner attaches them backward. They stay
   OUT of the skip declaration.
3. **Fresh-parse thresholds** are runtime strategy, not grammar — they
   stay on the engine facade.

## Toolchain loop

```
parsanol parg compile express.parg -o express.json   # + tables dir beside
parsanol parg test express.json                      # the grammar's own accepts
parsanol parg check --source express.parg --artifact express.json
```

Compile requires the full `use` closure in one directory (pubid bake
finding).

## Language facts learned while translating (parsanol 1.3.120/1.3.121)

- Parenthesized groups do NOT span newlines — multi-line rule bodies use
  the brace-block form (`rule = { ... }`), with the `as` inside.
- Self-references inside a grammar file are UNQUALIFIED; a qualified
  self-reference gets double-namespaced and fails.
- `use <grammar>` sections sit at TOP LEVEL (before the grammar block);
  imports resolve by FILENAME; chained/transitive imports and duplicate-
  import collision detection work.
- Entry targets must be LOCAL rules — alias imported rules and rebind
  explicitly (`digits = (express_literals.digits) as digits`), or the
  alias binds a namespaced tree key (a builder-parity trap).
- Backslash literals: the escaped form is rejected by the lexer — use
  `%x5C`.
- The `test` section's `accept` runs against the DEFAULT entry only;
  mid-migration probing uses declared entries instead.

- The skip rule must be NON-NULLABLE (`skip = trivia` with `1*`); the
  compiler rejects nullable skips (injection loops on empty). Injection
  itself is optional-before-every-terminal (parsanol-ruby#134) and
  entries get leading/trailing maybe-skips automatically.
- The `parg parse` CLI uses the FIRST declared entry when `--entry` is
  omitted — mid-migration probes must pass `--entry` explicitly.
