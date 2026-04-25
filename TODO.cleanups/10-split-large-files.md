# 10 — Split large files into focused modules (Layout/LineLength + file organization)

## Problem

Several files have grown too large and do too much. The top offenders:

| File | Lines | Role |
|------|-------|------|
| `lib/lutaml/xmi/parsers/xmi_base.rb` | 1047 | XMI parsing (13 Metrics offenses) |
| `lib/lutaml/uml_repository/index_builder.rb` | 480 | Index building (8 Metrics offenses) |
| `lib/lutaml/qea/database.rb` | 477 | QEA database (8 Metrics offenses) |
| `lib/lutaml/converter/xmi_to_uml.rb` | 474 | XMI→UML conversion (8 Metrics offenses) |
| `lib/lutaml/command_line.rb` | 272 | CLI option parsing |
| `lib/lutaml/uml_repository/static_site/data_transformer.rb` | ~950 | Static site generation |

Additionally, `Layout/LineLength` is globally disabled (80 offenses).

## Approach

### xmi_base.rb (1047 lines)
Split into:
- `xmi_base.rb` — shared module with common methods
- `connector_parser.rb` — connector-related parsing
- `diagram_parser.rb` — diagram-related parsing
- `element_parser.rb` — element-related parsing

### converter/xmi_to_uml.rb (474 lines)
Split into:
- `xmi_to_uml.rb` — main converter class
- Per-element mapping methods extracted into separate modules or classes

### database.rb (477 lines)
Already well-organized with lazy accessors. Split:
- `database.rb` — core + public API
- `lookup_indexes.rb` — the `build_lookup_indexes` method and index logic

### Layout/LineLength (80 offenses)
Re-enable the cop with a reasonable Max (120) and fix the worst offenders. Long lines often indicate:
- Deeply nested code → extract to methods
- Complex string interpolation → use `format` or heredocs
- Long method chains → use `tap` or break meaningfully

## Verification

- No file over ~300 lines in `lib/`
- `bundle exec rubocop --only Layout/LineLength` with `Max: 120` shows 0 offenses
- `bundle exec rspec` passes
