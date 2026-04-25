# 02 — Reduce Metrics/AbcSize and method complexity (212 + 130 + 11 + 11 + 8 offenses)

## Problem

5 Metrics cops account for **372 offenses** across production code. The worst offenders are large methods that do too much, making them hard to test, debug, and maintain.

## Top targets by file

| File | AbcSize | MethodLength | Cyclomatic | Perceived | Lines |
|------|---------|-------------|------------|-----------|-------|
| `lib/lutaml/xmi/parsers/xmi_base.rb` | Yes | — | Yes | Yes | 1047 |
| `lib/lutaml/converter/xmi_to_uml.rb` | Yes | — | Yes | Yes | 474 |
| `lib/lutaml/uml_repository/index_builder.rb` | Yes | — | Yes | Yes | 480 |
| `lib/lutaml/qea/database.rb` | Yes | — | Yes | Yes | 477 |
| `lib/lutaml/uml_repository/queries/class_query.rb` | Yes | — | Yes | Yes | 151 |
| `lib/lutaml/uml_repository/queries/inheritance_query.rb` | Yes | — | Yes | Yes | — |
| `lib/lutaml/model_transformations/parsers/base_parser.rb` | Yes | — | — | — | — |
| `lib/lutaml/qea/factory/enum_transformer.rb` | — | — | Yes | Yes | — |
| `lib/lutaml/uml_repository/queries/search_query.rb` | — | — | Yes | — | — |
| `lib/lutaml/cli/tree_view_formatter.rb` | — | — | Yes | — | — |

## Approach

Extract helper methods from god methods. Common patterns:

1. **xmi_base.rb** — The 1047-line file has massive parsing methods. Extract per-element-type parsing into separate methods (already partially done).
2. **converter/xmi_to_uml.rb** — The `build_*` methods handle too many concerns. Extract mapping logic per element type.
3. **index_builder.rb** — The single-pass `build_all` is better than before but individual index builders can be further split.
4. **database.rb** — The `build_lookup_indexes` method builds all indexes at once; split into per-index methods.

**Do NOT**: Increase Max thresholds in `.rubocop_todo.yml`. Instead, refactor to reduce actual complexity.

## Verification

- `bundle exec rubocop --only Metrics` shows reduced offense counts
- `bundle exec rspec` passes
- No functional changes — pure refactoring
