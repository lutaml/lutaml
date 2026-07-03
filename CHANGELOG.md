# Changelog

## v0.10.3 (2026-04-25)

### Performance

- Replace O(n) linear scans with O(1) hash lookups in QEA transformers
  and XMI parsers (connector, diagram, element lookups)
- Single-pass IndexBuilder replacing 9 separate tree traversals
- Memoized inheritance depth in StatisticsCalculator
- Set-based dedup in Repository associations_index

### Bug fixes

- Fix Windows EACCES: replace Tempfile.new with temp_lur_path helper
  to avoid file handle conflicts with rubyzip
- Fix xml_spec: use include matcher for platform-varying content nodes

### Improvements

- Consistent error hierarchy: all module error classes now inherit from
  `Lutaml::Error` (single rescue point for consumers)
- Fix gemspec email typo (mismatched quote)
- Bump required_ruby_version from >= 2.7 to >= 3.2 (matching CI)
- Rubocop: 0 offenses remaining

## v0.10.2 (2026-04-24)

### Bug fixes

- Fix Windows Errno::EACCES in PackageExporter: retry on file lock race
- Remove moxml git override (0.1.15 released)

## v0.10.1 (2026-04-23)

### Bug fixes

- Fix flaky CI tests: benchmark speedup assertion and Windows Tempfile race
- Fix xmi 0.5.6 compatibility: rename SparxRoot to Sparx::Root
- Fix nil @xmi_index in liquid drops: auto-init via xmi_index method
- Fix infinite loop in resolve_package_path with circular package hierarchy
- Fix stereotype type bugs, diagram package_id overwrite, and
  DataTypeTransformer crash
- Fix 46 pending/failing spec tests across QEA, verification, and liquid specs

## v0.10.0 (2026-04-21)

### Breaking changes

- Update to lutaml-model 0.8.0, expressir 2.3, and xmi 0.5.x
- Migrate Lutaml::Uml models to lutaml-model serialization
- Unify namespace of Sysml module

### Features

- Complete QEA to UML document migration
- Add PackagePresenter for structured output
- Add option to skip queries
- Add function to get qualified name
- Add Lutaml::Uml::Fidelity class
- Add attributes type, weight and status to Lutaml::Uml::Constraint
- Add generalization into Lutaml::Uml::Class
- Transform option keys to symbol
- Output find result based on format option
- Implement default sorting for diff_with_score comparison
- find_by_name returns single object instead of array

### Bug fixes

- Fix Windows EACCES file rename issues (Tempfile handle conflicts)
- Fix YAML disallowed class loading error
- Fix attribute parsing values
- Fix association loading by QEA parser
- Fix association_generalization parsed by xmi parser
- Fix certificate CRL error

## v0.9.43 (2025-11-20)

- Refactor klass_hash to use KlassDrop object in upper_klass

## v0.9.42 (2025-11-18)

- Directly convert XMI into UML

## v0.9.41 (2025-11-12)

- Remove unneeded version files
- Fix error when imports key is nil
- Unify Sysml namespace

## v0.9.40 (2025-11-10)

- Convert DSL to UML
- Change namespace of Formatter and HasAttributes
- Update GraphViz and related specs
- Add Lutaml::Uml::Fidelity class
- Remove duplicated GraphViz code
- Create Lutaml::Uml models by Xmi hash
- Migrate Lutaml::Uml models to lutaml-model

## v0.9.39 (2025-11-03)

- Change selection criteria for dependencies

## v0.9.38 (2025-10-31)

- Add subtype_of to klass and enum drop models
- Get stereotype by type idref in owned attribute
