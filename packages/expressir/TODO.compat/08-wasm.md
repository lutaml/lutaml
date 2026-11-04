# 08-wasm — WASM expressir-rs

 the Rust core compiled to WebAssembly for schema + instance validation in browser/Node. Acceptance: a wasm package validates a schema and a P21 population with parity to the native path on the conformance corpus.

## Status: done

- Rust surface (lutaml/expressir-rs#14): `src/p21.rs` parses the
  ISO-10303-21 exchange structure (header/FILE_SCHEMA, named data
  sections, entity/complex/typed records, anchors and external
  references, EXPRESS constant references) and validates record
  keywords against a schema inventory (clause 12); `src/wasm.rs`
  exposes `parse_schema` (declaration inventory through the full
  grammar engine), `parse_population` and `validate_population` over
  wasm-bindgen, wasm32-only.
- Package: `wasm-pack build --target nodejs --release` produces the
  browser/Node package.
- Parity harness:
  `spec/expressir/wasm_parity_spec.rb` — on the P21 conformance
  corpus (annexes E/H/I/J) the wasm schema parse returns the same
  entity inventory as the native path, every population parses with
  the same FILE_SCHEMA/instance/anchor/reference inventories, and the
  schema inventory validates the annex H population while a bogus
  inventory rejects it. Skipped when the package or node is absent;
  parity asserted whenever present.
