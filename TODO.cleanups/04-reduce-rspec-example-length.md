# 04 — Reduce RSpec/ExampleLength (657 offenses)

## Problem

657 test examples exceed the default 5-line limit (current Max: 108). Long examples are hard to read, hide intent, and often combine setup + action + multiple assertions.

## Approach

Common patterns to fix:

1. **Extract test data into `let`/`let!`** — Move setup out of `it` blocks:
```ruby
# BEFORE:
it "parses correctly" do
  result = described_class.parse(fixture_content)
  expect(result.name).to eq("Test")
end

# AFTER:
let(:result) { described_class.parse(fixture_content) }
it { expect(result.name).to eq("Test") }
```

2. **Extract shared setup into `before` blocks** — If multiple examples repeat the same setup.

3. **Use subject with one-liner syntax** — Where the subject is the tested value:
```ruby
subject { described_class.new(attrs) }
it { is_expected.to be_valid }
```

4. **Extract helper methods** — Complex assertions that span many lines can become custom matchers or helper methods in `spec/support/`.

## Priority

Focus on the longest examples first — run `bundle exec rubocop --only RSpec/ExampleLength` and sort by severity. Files with the worst examples:
- `spec/lutaml/qea/` verification and factory specs
- `spec/lutaml/uml_repository/` static site specs
- `spec/lutaml/cli/` command specs

## Verification

- `bundle exec rubocop --only RSpec/ExampleLength` shows reduced count
- Reduce Max from 108 toward 10
- `bundle exec rspec` passes
