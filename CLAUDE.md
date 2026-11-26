# CLAUDE.md — Lutaml

Lutaml is a single Ruby gem: the LutaML Model Language (LML) front-end —
grammar, domain models, model compiler, executor, format machinery and the
LSP server — on top of the canonical `lutaml-model` serialization gem.

## Layout
- `lib/lutaml/lml/` — the LML language: grammar (parsanol), models,
  model compiler, executor, formats, validator, LSP
- `lib/lutaml.rb` — entry: loads the LML tree; soft-loads lutaml-uml when present
- `spec/` — the LML spec suite (`bundle exec rspec`)
- `exe/` — executables (`lutaml-lml-lsp`)

## Dependencies
- `lutaml-model ~> 0.8.159` — the serialization runtime (canonical repo:
  lutaml/lutaml-model). NEVER vendor it here; NEVER add other gems'
  code to this repo — every gem lives in its own repository.
- `moxml`, `lutaml-uml`, `parsanol` per the gemspec.

## Testing
- `bundle exec rspec` runs the suite. Suites are fast; run targeted
  files for iteration.

## CI
- cimas-generated workflows (rake, release, docs, links). Releases ride
  `metanorma/ci/.../rubygems-release.yml`: the version bump lands as a
  release PR; publishing triggers when it merges.
