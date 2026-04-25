# 03 — Reduce RSpec/MultipleExpectations (946 offenses)

## Problem

946 test examples have more than 1 expectation. This is the single largest rubocop offense. It makes tests brittle (failures stop at the first failed expectation, masking other issues) and harder to understand what's being verified.

## Approach

Split multi-expectation examples into focused single-expectation examples:

```ruby
# BEFORE:
it "validates the widget" do
  expect(widget.name).to eq("Test")
  expect(widget.size).to eq(10)
  expect(widget.active).to be true
end

# AFTER:
it { expect(widget.name).to eq("Test") }
it { expect(widget.size).to eq(10) }
it { expect(widget.active).to be true }
```

For cases where multiple expectations are genuinely related (e.g., checking a hash structure), use compound matchers:

```ruby
expect(result).to include("name" => "Test", "size" => 10, "active" => true)
```

Or aggregate failures with `aggregate_failures` when the expectations are about the same concern:

```ruby
it "has correct address fields" do
  aggregate_failures do
    expect(address.street).to eq("Main St")
    expect(address.city).to eq("London")
  end
end
```

## Priority files (highest offense density)

Run `bundle exec rubocop --only RSpec/MultipleExpectations` to see the full list. Focus on:
1. `spec/lutaml/qea/verification/comprehensive_equivalence_spec.rb`
2. `spec/lutaml/qea/verification/equivalence_integration_spec.rb`
3. `spec/lutaml/cli/` command specs
4. `spec/lutaml/uml_repository/` specs

## Verification

- `bundle exec rubocop --only RSpec/MultipleExpectations` shows reduced count
- `bundle exec rspec` passes
- Reduce Max from 26 toward 5 (default)
