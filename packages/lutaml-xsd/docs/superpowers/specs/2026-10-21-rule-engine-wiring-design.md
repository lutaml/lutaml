# Design: wire the Ruby rule engine into production validation

- Date: 2026-10-21
- Status: implemented with this PR
- Scope: lutaml-xsd 1.1.x

## 1. Problem

`Validator#build_rule_registry` returns an **empty** registry, and
`RuleEngine#execute_rule` calls `rule.validate(document, repository,
collector)` while every concrete rule implements
`validate(instance_element, schema_definition, collector)`. Consequence:
the production validation stack runs zero rules. The conformance harness
(2026-10-20 baseline) measured pipeline mode == engine mode for exactly
this reason; every deferred rule-depth gap is blocked on this wiring.

## 2. Contract

Rules stay element-scoped. The engine walks the instance document
(depth-first over `XmlDocument#root_element` / `XmlElement#children`),
resolves each element's schema declaration, and dispatches:

```ruby
rule.validate(instance_element, rule.schema_argument(schema_def, repository:),
              collector, repository: repository)
```

- `ValidationRule#schema_argument(schema_def, repository:)` defaults to the
  resolved schema element; rules override it when they validate against
  something else (OccurrenceValidationRule returns the content-model
  particle of the schema element's type).
- `ValidationRule#runs_without_schema?` defaults false; the structure rule
  returns true so undeclared elements still produce findings (its
  element-existence check takes a nil declaration).
- `repository:` is the resolver (not the raw repository), giving rules
  named-type lookup (`resolve_type`) for `type="tns:…"` references.
- Dispatch order follows the existing categories:
  structure → type → constraint → facet → identity. Each rule invocation
  keeps `RuleEngine`'s existing per-rule rescue.

## 3. Schema definition resolution

`Validation::SchemaDefinitionResolver` indexes, per repository instance:

- top-level element declarations (`schema.element`)
- inline element declarations, recursively through complex types'
  sequence/choice/all particles and nested complex content

Matching: local name equality, plus namespace compatibility — a schema
with a target namespace matches only that namespace; a no-namespace schema
matches a no-namespace instance element. Top-level declarations win over
inline ones. `resolve_type(element)` finds a named complex/simple type for
`element.type` references across the repository's schemas.

Known limits (documented, deliberately deferred): dynamic typing
(`xsi:type`) and derivation closure are not resolved; UPA/identity
constraints remain rule-engine backlog items.

## 4. Registry population

`Validator#build_rule_registry` registers the five rules, gated by the
existing feature flags:

| rule | category | gate |
|---|---|---|
| ElementStructureRule | structure | always |
| ContentModelValidationRule | structure | `validate_content_models` |
| TypeValidationRule | type | `validate_types` |
| AttributeValidationRule | constraint | `validate_attributes` |
| OccurrenceValidationRule | constraint | `validate_occurrences` |

## 5. Testing

- Resolver specs with a real parsed schema and a minimal repository
  stand-in (top-level, inline, namespaced, unknown, type references).
- Engine integration: a `ValidationJob` with `engine_validation: false`
  and an invalid instance must now produce rule findings (previously an
  empty result). Valid instances stay clean.
- Conformance harness re-run; pipeline-mode pass-rate recorded.

## 6. Non-goals

- No new validation rules; this PR only makes the existing rules execute.
- No change to the engine fast-path or finding provenance.
