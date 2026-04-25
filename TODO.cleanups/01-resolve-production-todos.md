# 01 — Resolve 7 production TODOs

## Problem

Seven `TODO`/`FIXME` comments in `lib/` represent incomplete features, missing validation, or known tech debt. They risk silent data loss or incorrect behavior.

## Items

### 1. `lib/lutaml/qea/factory/diagram_transformer.rb:28`
```ruby
# TODO: Fix diagram_type assignment -
# lutaml-model compatibility issue
# diagram.diagram_type = ea_diagram.diagram_type
```
**Impact**: Diagram type is silently dropped during QEA→UML transformation. The `diagram_type` attribute exists on `Lutaml::Uml::Diagram` but is never populated from QEA.
**Fix**: Investigate lutaml-model compatibility (likely a type mismatch or missing attribute). Either fix the assignment or document why it's intentionally omitted.

### 2. `lib/lutaml/qea/factory/package_transformer.rb:32`
```ruby
# TODO: Fix tagged_values assignment - temporarily commented out
# pkg.tagged_values = load_tagged_values(ea_package.ea_guid)
```
**Impact**: Tagged values (metadata/annotations) are silently dropped from packages during QEA→UML transformation. This causes XMI/QEA equivalence mismatches.
**Fix**: Check if `load_tagged_values` returns correct type. Likely needs the same serialization pattern used in class_transformer.

### 3. `lib/lutaml/formatter/graphviz.rb:56`
```ruby
# TODO: set rankdir
# @graph['rankdir'] = 'BT'
```
**Impact**: Graph direction can't be configured. The value is commented out.
**Fix**: Either expose as configurable option or remove dead code.

### 4. `lib/lutaml/uml/node/class_node.rb:19`
```ruby
@modifier = value.to_s # TODO: Validate?
```
**Impact**: No validation on modifier values — invalid strings accepted silently.
**Fix**: Add enum validation for known modifiers (`public`, `private`, `protected`, etc.) or remove the TODO if validation isn't needed.

### 5. `lib/lutaml/uml/node/attribute.rb:27`
```ruby
@access = value.to_s # TODO: Validate?
```
**Impact**: Same as #4 but for access modifiers on attributes.
**Fix**: Same as #4 — validate or remove TODO.

### 6. `lib/lutaml/uml/node/class_node.rb:24`
```ruby
type = member.to_a[0][0] # TODO: This is dumb
```
**Impact**: Fragile parsing of member data structure. The `TODO: This is dumb` indicates the developer knew it was wrong but shipped it.
**Fix**: Replace with structured member parsing using named access.

### 7. `lib/lutaml/uml/has_members.rb:8`
```ruby
# TODO: move to Parslet::Transform
```
**Impact**: Member type logic is in the model instead of the parser layer.
**Fix**: Evaluate whether moving to Parslet::Transform is still desirable. If not, remove the TODO.

## Verification

- `grep -rn "TODO\|FIXME" lib/ --include="*.rb"` should return 0 results (or only intentional ones)
- Full test suite passes: `bundle exec rspec`
