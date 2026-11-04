# Lutaml::Jsonschema

**JSON Schema, fully legible** — a lossless typed model for machines and
Redoc-class, sovereign single-file documentation for humans, inside the
LutaML/metanorma standards ecosystem.

Parses JSON Schema documents (draft-04 through 2020-12, plus the
interagent-era hyper-schema corpus) into lutaml-model objects, resolves and
bundles `$ref` graphs (local pointers, cross-file, and opt-in remote HTTP(S)
with an offline SHA-256 cache), validates against fully vendored
meta-schemas, diffs schema versions with breaking-change classification, and
generates a self-contained documentation SPA — no runtime fetches, no
network, one `index.html`.

**The model is lossless**: every keyword the Ruby model does not name —
vendor `x-*` extensions, dialect additions, hyper-schema keywords — is
collected verbatim and re-emitted on serialization (`map_unmapped`).

## Installation

```bash
gem install lutaml-jsonschema
```

or add to your Gemfile:

```bash
bundle add lutaml-jsonschema
```

## CLI

```bash
# generate the single-file documentation SPA
lutaml-jsonschema spa SCHEMA_FILES... [--diff BASELINE...] [-c CONFIG.yml]

# merge schema documents into one bundle
lutaml-jsonschema combine SCHEMA_FILES...

# export to other data-definition languages
lutaml-jsonschema export SCHEMA_FILES... -f cddl|openapi|xsd|adoc|lml

# semantic diff; exits non-zero when a breaking change is found
lutaml-jsonschema diff OLD_SCHEMA NEW_SCHEMA [--format json]

# validate against the dialect's meta-schema (offline; --format json)
lutaml-jsonschema validate SCHEMA_FILE
```

The SPA supports light/dark themes, FlexSearch search, per-property and
per-definition detail views, composition tabs, a JSON builder, a change view
(`--diff`), RTL locales (`?locale=ar`), and prints to PDF.

## Library

```ruby
require "lutaml/jsonschema"

schema = Lutaml::Jsonschema::Schema.from_json(json_string)
schema.extensions          # => unknown keywords, preserved verbatim
schema.to_json             # lossless re-emission

set = Lutaml::Jsonschema::SchemaSet.load_from_files(*paths)
set.bundle                 # hoist definitions, rewrite refs
set.dereference("demo")    # resolve the $ref graph

Lutaml::Jsonschema::Exports::Cddl.new(set).render    # RFC 8610
Lutaml::Jsonschema::Exports::Openapi.new(set).render # OAS 3.1 components
Lutaml::Jsonschema::Exports::Xsd.new(set).render     # W3C XML Schema
Lutaml::Jsonschema::Exports::Adoc.new(set).render    # AsciiDoc reference
Lutaml::Jsonschema::Exports::Lml.new(set).render     # LutaML UML models

Lutaml::Jsonschema::Diff.between(old_schema, new_schema) # classified changes
```

`SchemaStore` (a `SchemaSet` subclass) adds on-disk persistence through
[lutaml-store](https://github.com/lutaml/lutaml-store).

## JSON engine

Parsing rides [yeptris](https://github.com/leptris/yeptris-ruby), the org's
native YAML/JSON engine (FFI over libyeptris, strict RFC 8259 semantics with
`JSON.parse` parity), auto-detected by lutaml-model for both JSON and YAML.
JSON generation stays on the stdlib `json` gem.

## Development

```bash
bundle exec rake            # specs + rubocop + perf gate + axe AA audit
bundle exec rspec           # full suite
cd frontend && npm test     # SPA unit tests
bundle exec rake frontend:build   # build frontend/dist (needed for spa)
```

CI runs the full matrix (3 Ruby lines × ubuntu/macos/windows) on every push,
including the browser gates (headless-Chrome boot, PDF, RTL render) and the
WCAG AA audit. `spec/fixtures/` carries the real-world corpora (heroku,
interagent) the specs round-trip.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/lutaml/lutaml-jsonschema.
