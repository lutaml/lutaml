# CLAUDE.md — Lutaml Project

## Project Overview
Lutaml is a Ruby gem for parsing and transforming UML models from multiple formats (XMI, QEA/EA, DSL). It provides a CLI, interactive shell, static site generator, web UI, and model transformation pipeline.

## Testing Constraints

**CRITICAL: Do NOT run the full test suite at once.** It will crash due to memory. Run targeted subsets:
- `bundle exec rspec spec/lutaml/cli/` — CLI specs
- `bundle exec rspec spec/lutaml/qea/` — QEA parser specs
- `bundle exec rspec spec/lutaml/uml_repository/` — UML repository specs
- `bundle exec rspec spec/lutaml/uml/` — UML model specs
- `bundle exec rspec spec/lutaml/parsers/` — Parser specs
- `bundle exec rspec spec/lutaml/formatter/` — Formatter specs
- Combine at most 2-3 suites at a time for targeted verification.

## Code Quality Rules
- Never use `send` (breaks encapsulation). Use `public_send` only when dynamic dispatch is truly necessary.
- Never use `respond_to?` (poor typing). Use `is_a?` for type checks.
- Extract god methods into focused helpers.
- Keep files under ~300 lines. Extract into modules/classes when growing.
- DRY: consolidate duplicated patterns (especially `format_definition`, index building, metadata construction).
- Never commit TODO tracking files to git.

## Architecture
- `lib/lutaml/uml/` — UML domain models (Class, Association, Package, etc.)
- `lib/lutaml/uml_repository/` — Repository pattern over UML documents (queries, presenters, exporters, SPA)
- `lib/lutaml/qea/` — EA .qea SQLite parser and factory
- `lib/lutaml/xmi/` — XMI XML parsing
- `lib/lutaml/converter/` — Format converters (XMI→UML, DSL→UML)
- `lib/lutaml/cli/` — Thor CLI commands
- `lib/lutaml/model_transformations/` — Format-agnostic transformation pipeline
- `lib/lutaml/ea/` — EA diagram SVG rendering

## CI Notes
- Ignore Ruby 3.4 ubuntu failures (performance-related, not code issues)
- Ignore macOS job slowness (GitHub Actions is slow for macOS)
- Windows tempfile Permission denied errors are pre-existing flakiness
