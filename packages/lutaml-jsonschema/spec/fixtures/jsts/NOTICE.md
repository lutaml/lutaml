# Vendored JSON-Schema-Test-Suite fixtures

Source: https://github.com/json-schema-org/JSON-Schema-Test-Suite
Fetched: 2026-10-21 from the `main` branch (`tests/draft2020-12/`,
`tests/draft7/`).

Only a representative subset of suite files is vendored — enough to keep
the meta-schema corpus honest in CI without carrying the full tree:

- draft2020-12: type, enum, patternProperties, unevaluatedProperties, ref
- draft7: type, enum, if-then-else

Do not edit these files; re-fetch from the canonical URLs above.
