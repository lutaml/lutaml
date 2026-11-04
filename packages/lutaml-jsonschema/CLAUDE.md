# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`lutaml-jsonschema` parses JSON Schema documents into lutaml-model objects and generates a single-file SPA documentation site from them. It has two halves that must stay in sync:

1. **Ruby gem** (`lib/lutaml/jsonschema/`) — the JSON Schema model and documentation generator.
2. **Vue 3 frontend** (`frontend/`) — the SPA itself. The built bundle (`frontend/dist/app.iife.js` + `style.css`) gets inlined into a standalone `index.html`.

## Commands

```sh
bundle exec rspec                          # full suite
bundle exec rspec spec/lutaml/cli_spec.rb  # one file
bundle exec rspec spec/lutaml/cli_spec.rb:76  # one example
bundle exec rubocop                        # lint (-a to autofix; .rubocop_todo.yml holds baselined offenses)
bundle exec rake                           # spec + rubocop + perf gate + axe AA audit (what CI runs)

bundle exec rake frontend:build            # npm install + vite build → frontend/dist
cd frontend && npm test                    # vitest (frontend unit tests)

bundle exec exe/lutaml-jsonschema spa SCHEMA_FILES... [--diff BASELINE...]
bundle exec exe/lutaml-jsonschema combine|validate SCHEMA_FILES...
bundle exec exe/lutaml-jsonschema export SCHEMA_FILES... -f cddl|openapi|xsd|adoc|lml
bundle exec exe/lutaml-jsonschema diff OLD NEW [--format json]
```

`frontend/dist/` and `Gemfile.lock` are gitignored. `frontend/dist/` must exist (run `rake frontend:build`) for the `spa` command and for packaging — the gemspec ships it via `Dir.glob("frontend/dist/*")`.

## Architecture

Data flow: schema files → `SchemaSet.load_from_files` → `Spa::SpaBuilder` → `Spa::SpaDocument` → `to_json` → `Spa::VueInlinedStrategy` (embeds `window.SCHEMA_DATA` + inlined JS/CSS into `index.html`).

- **`Base`** — everything inherits from `Lutaml::Model::Serializable`. `Base` also forward-declares `Schema` to break the circular `Schema ↔ PropertyEntry ↔ Link` references.
- **`Schema`** — the central model of a JSON Schema document. Every `$`-prefixed keyword is a `dollar_`-prefixed attribute (`$schema` → `dollar_schema`) via json mappings. `Schema.from_json` / `to_json` are lutaml-model serialization. The model is **lossless**: `map_unmapped to: :extensions` collects every unmodeled keyword (vendor `x-*`, dialect additions) verbatim and re-emits it — new keywords land as attributes, not in a hand-rolled serializer.
- **`SchemaSet`** — in-memory named collection of schemas plus `$ref` resolution (local `#/...` pointers and relative `./file.json` refs through `ReferenceResolver`) and validation.
- **`SchemaStore`** — `SchemaSet` subclass that adds on-disk persistence through **lutaml-store** (`PackageStore`, package shape from `LjrPackageDefinition`).
- **`Combiner`** — compatibility facade; bundling lives in `SchemaSet#bundle` (hoists definitions, adds a top-level `$ref` property per source schema, rewrites `#/definitions/` → `#/$defs/`).
- **`Spa::*`** — `SpaBuilder` flattens a `SchemaSet` into a `SpaDocument` (metadata, `SpaSchema` list, flat `search_index` for FlexSearch). `Spa::Generator` renders through an `OutputStrategy`; `VueInlinedStrategy` is the only implementation.
- **`Configuration`** — YAML config for the SPA (title, theme, appearance…), loaded by `Cli#spa -c`.
- **`Cli`** — Thor commands: `spa` (generate docs; `--diff` embeds a classified change set), `combine` (merge schemas), `export` (cddl/openapi/xsd/adoc/lml; adoc `--embeddable` drops the level-0 title and namespaces anchors for Metanorma `include::`), `diff` (exits 1 on breaking changes), `validate` (offline meta-schema checks against fully vendored meta-schemas, JSON Pointer error paths), `version`.
- **`Exports::*`** — one renderer per target language (CDDL, OpenAPI 3.1, XSD, AsciiDoc, LML); all read the same `SchemaSet`, and each documents its approximations on the class. LML output parses back through `lutaml-lml`; CDDL through the RFC 8610 reference parser.
- **`TupleItem`** — schema-or-boolean wrapper used by `items`/`prefixItems` arrays and composition collections; models that accept `true`/`false` store booleans in companion `*_boolean` attributes and expose `*_value` helpers.

## JSON engine: yeptris

Two distinct paths, both engine-backed:

- **Direct parsing** in this gem (`Cli#combine`, `Cli#validate`, `Schema.serialize_additional_properties`) uses `Yeptris::JSON.load` — strict RFC 8259, exact-`JSON.parse` semantics, raises `Yeptris::JSON::ParseError`. JSON **generation** stays on the stdlib `json` gem (`JSON.pretty_generate`); yeptris's JSON surface is load-only.
- **Model serialization** (`Schema.from_json`/`to_json`, `Configuration.from_yaml`, lutaml-store I/O) goes through lutaml-model, whose `AdapterResolver` auto-detects yeptris from the bundle and routes both `:json` and `:yaml` to its `YeptrisAdapter`. That adapter re-raises parse failures as `JSON::ParserError`, so error handling must cover **both** exception types — see the rescue in `Cli#validate`.
- Raw-parse speed depends on the resolved yeptris build shipping a **native materializer for the running Ruby version**; without one it falls back to a pure-Ruby tape engine that is several times slower than `JSON.parse` on large documents (yeptris-ruby#278). Check with `defined?(Yeptris::Native)` (0.6.28.x shipped only Ruby 3.3; 3.4-native starts at 0.6.29.1).
- The GC-pressure SIGSEGV in the native JSON materializer (yeptris-ruby#279) is fixed in the yeptris **0.6.34 line** (staged pairs made GC-visible); excluding the crashy 0.6.29.x–0.6.33.x native builds. Env-gated canary: yeptris-ruby#280.
- The 0.6.34 C **strict-dup pre-scan** was broken (one shared key table, no growth — false duplicates on ordinary schemas, hang on the 17th distinct key); fixed in yeptris v0.6.35 (per-container frame stacks). Lanes without a native materializer (all Windows) ride that marshal route, so engine bugs surface there first.
- The marshal route's strict-dup scan carried a second latent false-positive — three equal array elements inside an object (`{"a":[1,1,1]}`) raised `duplicate key in object` — present since ~0.6.36 and reachable once json 3 turned the strict flag on; fixed in yeptris **0.6.51** (yeptris-ruby#333). The gemspec floors at `~> 0.6.51` (the 0.6.51 release train also fixed its musl/qemu container legs racing the fresh release tag).

## Frontend: i18n, RTL, a11y

- All UI strings come from the typed catalog `frontend/src/i18n/messages.ts` (`en` + `ar`); `t()`/`tf()` read a Vue ref, so the header switch re-renders live. A missing key in a locale is a type error — add both languages.
- The locale mirrors `lang`/`dir` onto `<html>`; layout uses CSS logical properties (`*-inline-*`), so RTL needs no second stylesheet. `?locale=ar` boots straight into a locale.
- `script/axe_audit` (in the default `rake` gate) scans the generated site with the vendored axe-core; browser-less lanes skip cleanly. The browser specs (boot, PDF, RTL render) run wherever Chrome exists.

## Repo notes

- `TODO.redoc/`, `TODO.refactor/`, `TODO.store/` are untracked, numbered working notes (known gaps and planned refactors), not code. `TODO.sota/` holds the SOTA program (purpose, per-area tasks with done-when criteria, and the goal prompt).
- CI is metanorma/ci's `generic-rake` workflow; releases run through `.github/workflows/release.yml`.
- Ruby 4.0 binds brace-less hash literals as keyword arguments — always brace hashes passed to positional-only methods (specs included).
