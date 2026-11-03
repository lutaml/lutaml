## [Unreleased]

## [0.1.27] - 2026-10-31

- Add the BSD-2-Clause license (LICENSE.md + `spec.license`) and backfill
  the changelog for 0.1.16–0.1.26
- Floor yeptris at the fixed `~> 0.6.51` line (marshal strict-dup
  false-positive fixed, yeptris-ruby#333)
- Frontend dev toolchain bumped past the vulnerable ranges
- lychee-action bumped to v2

## [0.1.26] - 2026-10-28

- Accept YAML schema inputs (`SourceFile` records) alongside JSON
- Fix AsciiDoc links to resolved schema targets; reference-link audit
- Audit the Arabic RTL render in the axe gate
- Real README; CLAUDE.md refreshed for the SOTA state
- Pin Parsanol for the LML round-trip test

## [0.1.25] - 2026-10-22

- Fully lossless model: unknown keywords and `x-*` extensions preserved via
  `map_unmapped` (lutaml-model `~> 0.8.122`)
- RTL-safe layout (CSS logical properties + document `dir` mirroring),
  Arabic locale with live switch, RTL render proven in headless Chrome
- axe-core AA audit in the default `rake` gate with vendored axe
- LML exporter (`export --format lml` via lutaml-lml)
- Metanorma-embeddable AsciiDoc (`--embeddable`) and CDDL round-trip through
  the RFC 8610 reference parser (`pstore` declared for Ruby 4.0)
- Dialect semantics annotations for `$ref` siblings and format assertions
- Ruby 4.0: brace hash literals in specs passed to `dump`

## [0.1.24] - 2026-10-21

- Generated SPA passes an axe-core AA scan
- Frontend built in rake CI; fixed the rake workflow startup failure
- Perf caps calibrated per environment; `benchmark` gem declared for Ruby 4.0

## [0.1.23] - 2026-10-20

- yeptris as the JSON parse engine, floored at the fixed `~> 0.6.34` line
  (fixes the native materializer SIGSEGV and the tape-engine perf gap)
- CLAUDE.md with repo commands and architecture

## [0.1.22] - 2026-10-19

- Floor lutaml-model at `~> 0.8.114`

## [0.1.21] - 2026-10-02

- Maintenance release (release-train CI fixes ride along from 0.1.20)

## [0.1.20] - 2026-10-01

- Release `post_install` hardened: `npm ci` against the runner-synced lock
  without touching tracked files

## [0.1.19] - 2026-06-08

- Fix all SPA data gaps for complex schemas (0.1.18 line)
- Appearance config support for logos and subtitle
- Comprehensive code-quality audit (311 specs, 0 failures)
- Remove the local lutaml-store path override for CI

## [0.1.17] - 2026-05-27

- Resolve array items `$ref` and expose definition-level constraints
- Render `itemsRef` and definition constraints

## [0.1.16] - 2026-05-14

- Frontend range tests (numberRange/stringRange/itemsRange) and
  jsonToCollapsibleHtml edge cases
- Hardcoded rgba replaced with CSS variables; rubocop baseline refresh

## [0.1.15] - 2026-05-10

### Redoc-style UX improvements (round 16)

- DetailPanel descriptions rendered with inline markdown (bold, italic, code, links)
- Source viewer URLs are clickable links (Redoc jsonToHtml pattern)
- Definition mini-table rows show description tooltip on hover
- SeeMore component uses scrollHeight-based overflow detection (Redoc SeeMore pattern)
- Landing page schema grid has search/filter input
- Property sort toggle in SchemaBuilder (alphabetical vs required-first, Redoc sortPropsAlphabetically pattern)
- Schema header meta badges with colored count chips (properties, required, definitions)
- DetailPanel dark mode support (constraint colors, enum chips, example blocks)

### Redoc-style UX improvements (round 17)

- Sidebar tree shows properties alongside definitions with type labels
- Copy link button in schema header for sharing current view via URL
- selectedPropertyName computed added to schema store

### Redoc-style UX improvements (round 18)

- Mini-table required field names shown in bold with red asterisk (Redoc RequiredLabel pattern)
- Mini-table shows uniqueItems badge for properties with unique constraint
- Mini-table shows array items type `[type]` for array properties
- Mini-table shows all properties when <= 8 (smart limit)

### Redoc-style UX improvements (round 19)

- Floating back-to-top button appears after scrolling 300px down
- Back-to-top button responsive on mobile (smaller, closer to edge) (constraint colors, enum chips, example blocks)

## [0.1.14] - 2026-05-10

### Redoc-style UX improvements (round 15)

- Markdown renderer converts `\n` to `<br>` for multi-line descriptions
- Definition mini-table shows `$ref` target name with clickable navigation
- Definition mini-table shows `const` badge for constant properties
- Definition mini-table shows deprecated strikethrough on property names
- Definition mini-table shows `N enum` label instead of just count
- Definition card header shows `N examples` instead of `N ex`
- Definition card expanded body shows required fields list and examples section
- DetailPanel properties tab rows are clickable (navigate to property)
- DetailPanel properties tab shows `$ref` target with clickable link
- Improved circular reference label (shows type badge, name, hint text)
- Source viewer: click on line number to highlight it
- Landing page card descriptions rendered with markdown
- Keyboard shortcut: `/` focuses search input from anywhere
- Search input placeholder shows shortcut hint
- Search results expand schema tree node automatically
- Hash navigation expands schema tree node automatically
- Definition mini-table type badges color-coded by type (string/number/integer/boolean/object/array)
- Definition mini-table rows show hover effect

## [0.1.13] - 2026-05-10

### Backend: property-level composition resolution

- Resolve `allOf` properties by merging sub-schemas into a unified type with merged properties
- Resolve `anyOf`/`oneOf` properties by showing variant type labels (e.g. `anyOf: object | object`)
- Resolve `not` properties with negated type label (e.g. `not string`)
- Extract `$ref` from allOf sub-schemas for frontend definition expansion
- Extract `resolve_prop_ref` helper to reduce complexity in `build_single_property`

### Redoc-style UX improvements (round 7)

- SeeMore description fade uses CSS mask-image instead of background gradient (works on any background)
- Array type badge shows items range constraint inline (e.g. `array of string [ 1 .. 10 ]`)
- Schema tree sidebar shows property count badge (P) alongside definition count (D)
- Definition mini-table shows format (`<email>`) and enum count badges
- Definition card description truncated to 2 lines when collapsed
- Landing card stats show min/max properties count

### Redoc-style UX improvements (round 8)

- Auto-expand definitions with single property (Redoc expandSingleSchemaField pattern)
- Clickable $ref navigation — clicking ref chip scrolls to definition
- Source viewer line numbers highlight on hover
- Definition mini-table shows composition source (allOf/anyOf/oneOf) badges
- Scroll centering for definition and property navigation

### Redoc-style UX improvements (round 9)

- Definition card header shows required field names when ≤3 required fields
- JSON preview shows hint when no fields are checked
- Definition expanded body shows title, type, property count, and composition badges

### Redoc-style UX improvements (round 10)

- Clickable $id/$schema URLs in schema header (opens in new tab)
- Keyboard support for definition card toggle (Enter/Space)
- Nested builder shows parent property path breadcrumb

### Redoc-style UX improvements (round 11)

- Composition type badges with teal color coding (type-composition class)
- Static label for composition properties instead of editable input
- `isCompositionType()` helper for frontend composition type detection
- Skip validation for composition type properties

### Redoc-style UX improvements (round 12)

- DetailPanel: clickable $ref link navigates to definition (closes panel, scrolls to def)
- DetailPanel: readOnly/writeOnly access badges in property overview
- DetailPanel: enum values shown as individual chips instead of comma-separated list
- DetailPanel: schema overview shows property count and definition count

### Redoc-style UX improvements (round 13)

- Search results show description snippets (truncated to 80 chars)
- Schema header breadcrumb shows Schema > Definition when a definition is selected
- Clickable breadcrumb link navigates back to schema overview

### Redoc-style UX improvements (round 14)

- Property filter in SchemaBuilder when schema has >8 properties (filters by name, title, description, type)
- Markdown renderer handles fenced code blocks (` ```code``` `)
- Global CSS for markdown pre/code blocks in descriptions

## [0.1.12] - 2026-05-10

### Redoc-style UX improvements (round 6)

- Property title display in type row when it differs from name (Redoc TypeTitle pattern)
- Copy fallback using `execCommand('copy')` for HTTP contexts where clipboard API unavailable
- Dark panel full-height background via BackgroundStub `::before` pattern
- Search result description snippets in search modal
- Tooltip with directional CSS arrow on copy buttons
- DetailPanel properties table: shows title, format with angle brackets, default value, enum count, inline examples

## [0.1.11] - 2026-05-09

### Redoc-style UX improvements (round 5)

- Dark JSON preview panel with themed syntax colors in SchemaBuilder
- Select-on-click for source viewer and builder JSON blocks (double-click to select all)
- Print stylesheet: hides sidebar, header, controls; content prints full-width
- Format badges display with angle brackets (`<email>`) and accent color
- Responsive builder layout: stacks vertically on mobile (<768px)

## [0.1.10] - 2026-05-09

### Redoc-style UX improvements

- JSON viewer collapsed objects show key names (e.g. `{a, b, c}`), arrays show item count
- Sidebar auto-scrolls to active schema node on selection
- Search results sorted by relevance: exact name > starts with > contains > description
- Copy button shows positioned tooltip overlay instead of text swap
- Mobile sidebar backdrop overlay (click-to-close)
- DetailPanel overview shows definition-level metadata: required fields, composition badges, property range, additionalProperties
- Nullable badge for union types (e.g. `string,null`) in SchemaBuilder
- Focus trap in DetailPanel: focus moves to panel on open, Tab/Shift+Tab trapped, Escape closes

## [0.1.0] - 2026-05-05

- Initial release
