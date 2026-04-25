# 07 — Fix Lint offenses (15 + 8 + 4 + 3 + 4 + 1 + 1 = 36 offenses)

## Problem

Lint cops catch real bugs and code quality issues. 36 offenses across 7 Lint cops.

## Items

### 1. Lint/DuplicateBranch (8 offenses)
Identical code in different `case`/`if` branches — likely copy-paste bugs or missing differentiation.
```
lib/lutaml/cli/element_identifier.rb
lib/lutaml/cli/uml/verify_command.rb
lib/lutaml/qea/factory/base_transformer.rb
lib/lutaml/qea/models/ea_datatype.rb
lib/lutaml/qea/validation/validation_engine.rb
lib/lutaml/uml_repository/queries/package_query.rb
lib/lutaml/uml_repository/static_site/configuration.rb
lib/lutaml/uml_repository/static_site/search_index_builder.rb
```
**Fix**: Merge duplicate branches or differentiate them if they should do different things.

### 2. Lint/IneffectiveAccessModifier (4 offenses)
`private`/`protected` used inside a `class << self` block — doesn't actually restrict access.
```
lib/lutaml/uml_repository/repository_enhanced.rb
```
**Fix**: Move methods outside the singleton class or use `private_class_method`.

### 3. Lint/ConstantDefinitionInBlock (15 offenses)
Constants defined inside `it`/`before` blocks leak and can cause test pollution.
```
spec/lutaml/model_transformations/format_registry_spec.rb
spec/lutaml/model_transformations/parsers/base_parser_spec.rb
spec/lutaml/model_transformations/transformation_engine_spec.rb
spec/lutaml/model_transformations_spec.rb
spec/lutaml/uml_repository/presenters/presenter_factory_spec.rb
```
**Fix**: Extract to top-level constants, use `stub_const`, or define in a shared context.

### 4. Lint/EmptyConditionalBody (3 offenses)
`if`/`unless` with empty body — likely incomplete logic.
```
spec/integration/qea_xmi_equivalency_spec.rb
spec/lutaml/qea/verification/equivalence_integration_spec.rb
```
**Fix**: Add the missing body or refactor to use a guard clause.

### 5. Lint/EmptyBlock (4 offenses)
Empty blocks passed to methods — likely stub placeholders.
```
spec/lutaml/qea/integration/tagged_values_integration_spec.rb
spec/lutaml/qea/services/database_loader_spec.rb
spec/lutaml/uml_repository/package_exporter_spec.rb
spec/lutaml/uml_repository/repository_spec.rb
```
**Fix**: Remove empty blocks or add `{ }` style comment if intentional.

### 6. Lint/BinaryOperatorWithIdenticalOperands (1 offense)
```ruby
# spec/lutaml/qea/lookup_tables_spec.rb
```
**Fix**: Likely a test typo — check if both operands should be the same.

### 7. Lint/MissingSuper (1 offense)
```ruby
# lib/lutaml/uml_repository/lazy_repository.rb
```
**Fix**: Add `super` call or document why it's intentionally omitted.

## Verification

- `bundle exec rubocop --only Lint` shows 0 offenses
- `bundle exec rspec` passes
