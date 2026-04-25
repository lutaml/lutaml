# 08 — Reduce RSpec/MultipleMemoizedHelpers (130) and RSpec/NestedGroups (29)

## Problem

130 examples exceed memoized helper limits (Max: 11) and 29 examples have excessive nesting (Max: 5). Both indicate test organization issues.

## RSpec/MultipleMemoizedHelpers (130)

Too many `let`, `let!`, `subject` declarations make test setup hard to follow. Each helper adds cognitive load.

### Approach
1. **Group-related helpers into factory methods** — Instead of 10 separate `let` declarations, use one factory:
```ruby
# Instead of:
let(:name) { "Test" }
let(:age) { 30 }
let(:address) { Address.new(city: "London") }
let(:person) { Person.new(name: name, age: age, address: address) }

# Use:
let(:person) { build(:person) }  # via FactoryBot or test factory
```

2. **Use `subject!` instead of separate `let` + action** — Combine setup and action.

3. **Extract shared contexts** — Move common setup into `shared_context` blocks.

### Priority files
These are the worst offenders — check with `bundle exec rubocop --only RSpec/MultipleMemoizedHelpers`.

## RSpec/NestedGroups (29)

Deeply nested `describe`/`context` blocks (5+ levels) make tests hard to scan.

### Approach
1. **Flatten by using more descriptive top-level descriptions** — Instead of 3 levels of nesting, use a single `describe` with a descriptive name.
2. **Extract nested contexts into separate `describe` blocks** — Move `context "when X"` / `context "and Y"` into `context "when X and Y"`.
3. **Use shared examples** — Repeated nested structures can become shared examples.

## Verification

- `bundle exec rubocop --only RSpec/MultipleMemoizedHelpers,RSpec/NestedGroups` shows reduced counts
- `bundle exec rspec` passes
