# 04 — LSP + incremental platform

Make Expressir IDE-grade. The resolution/checking machinery is the
hard part and it exists; this task wires it to a language server.

## Parts (each ships)

1. Scaffold: `expressir-lsp` (solo binary or gem — decide by the
   metanorma toolchain's needs) speaking stdio LSP 3.17: initialize,
   diagnostics push, document symbols.
2. Diagnostics: Checker notes as publishDiagnostics with model-node
   → LSP range mapping (NodePositionIndex exists).
3. Navigation: definition (ScopeResolver + the USE/REFERENCE ladder +
   alias map), references, document/rename — rename updates the
   model in place and re-emits via the Formatter (the compare/patch
   engine provides the structural diff safety net).
4. Hover: PrettyFormatter excerpt of the target declaration + its
   remarks.
5. Incremental: document-open/parse via the expressir-rs core path
   when available (parsanol incremental machinery); fallback full
   reparse. Cold-open target: SRL-scale schema set interactive on
   this box.

## Acceptance

- A live editor session on the stepmod corpus: diagnostics on open,
  go-to-definition across a USE ladder, rename across two schemas
  with the diff verified by SchemaCompare.

## Status: done

- Part 1 (scaffold): `exe/expressir-lsp` ships in the gem
  (`executables`), speaking JSON-RPC 2.0 over stdio with LSP 3.17
  framing (`Content-Length`), lifecycle (initialize/shutdown/exit) and
  full-sync text documents (didOpen/didChange/didSave/didClose).
  `Expressir::Lsp::{Document,Workspace,Server}` are autoloaded from
  `lib/expressir/lsp.rb`.
- Part 2 (diagnostics): `Workspace#diagnostics` runs the Checker over
  the open documents, maps notes through NodePositionIndex/LineMap to
  byte→UTF-16 ranges, and publishes `textDocument/publishDiagnostics`.
  Parse failures publish a diagnostic at the reported line/char and
  keep the last good tree for navigation. Cross-document unresolved
  notes are suppressed when another open document supplies the
  referenced schema or interfaced declaration (the checker sees one
  file at a time).
- Part 3 (navigation): definition resolves declaration tokens,
  local references, the USE/REFERENCE ladder and its alias map
  (`colour AS hue` jumps to `colour`); references walks every open
  document and interface item; rename computes minimal edits for the
  declaration and every reference across schemas, then applies them in
  memory, verifies each document reparses, runs SchemaCompare to
  reject any removal other than the renamed declaration, and re-emits
  the renamed schema through the Formatter to prove it formats. Rename
  keeps aliases untouched: only the imported name at the interface
  item and usages written with the original name change.
- Part 4 (hover): `Express::PrettyFormatter` excerpt in a markdown
  `express` code fence (remarks included by the formatter).
- Part 5 (incremental): changes reparse through the native/core parser
  path; identical text is a no-op and checker results are memoized
  across requests for the same document set. There is no incremental
  parse API in the expressir-rs core to call, so true content-
  incremental reparse remains a measured gap: cold open of the 186 KB
  geometric_model_schema on this loaded box takes ~9.4 s (document
  parse) and ~0.03 s for the symbol index. Recorded for an
  expressir-rs incremental API when it exists; semantics stay Ruby.
- Specs: `spec/expressir/lsp/document_spec.rb` (positions, UTF-16,
  tokens, symbols, parse-failure retention) and
  `spec/expressir/lsp/server_spec.rb` (capabilities, diagnostics,
  symbols, USE/alias definition, references, hover, cross-schema
  rename verified by SchemaCompare and Formatter) — 14 examples.
