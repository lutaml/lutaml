# 09 — Reduce RSpec/VerifiedDoubles (212) and other RSpec style offenses

## Problem

212 test doubles don't verify their methods exist against real classes. Other RSpec style issues total ~130 additional offenses.

## RSpec/VerifiedDoubles (212 offenses)

Currently disabled entirely (`Enabled: false`). Every mock/stub in the test suite uses unverified doubles:

```ruby
# CURRENT (unverified):
let(:database) { instance_double("Database") }
allow(database).to receive(:find_object).with(1).and_return(obj)

# SHOULD BE (verified):
let(:database) { instance_double(Lutaml::Qea::Database) }
# Now rubocop verifies `find_object` is a real method
```

### Approach
1. Re-enable the cop in `.rubocop_todo.yml` but with a high initial Max
2. Fix in batches per directory:
   - `spec/lutaml/qea/` (highest density)
   - `spec/lutaml/uml_repository/`
   - `spec/lutaml/cli/`
   - rest
3. Replace `double(...)` with `instance_double(RealClass, ...)` or `class_double(RealClass, ...)`
4. Remove any stubbed methods that don't exist on the real class (they were wrong)

### Risk
Fixing verified doubles may expose test/implementation drift where tests mock methods that no longer exist. This is valuable — it means the tests were providing false confidence.

## Other RSpec style offenses to fix in same pass

| Cop | Count | Fix |
|-----|-------|-----|
| RSpec/ContextWording | 25 | Prefix with "when"/"with"/"without" |
| RSpec/ExpectOutput | 90 | Use `expect { }.to output().to_stdout` |
| RSpec/InstanceVariable | 48 | Replace `@var` with `let` (except `before(:all)` blocks) |
| RSpec/RepeatedExample | 16 | Remove or differentiate duplicate test cases |
| RSpec/LeakyConstantDeclaration | 15 | Use `stub_const` instead of defining constants in tests |
| RSpec/MessageSpies | 11 | Use `have_received` instead of `receive` with `allow` |
| RSpec/UnspecifiedException | 6 | Specify exception class in `expect { }.to raise_error(SomeError)` |
| RSpec/SpecFilePathFormat | 6 | Rename spec files to match their described class |
| RSpec/IndexedLet | 5 | Rename `thing1`, `thing2` to descriptive names |
| RSpec/RepeatedExampleGroupDescription | 2 | Rename duplicate describe/context descriptions |
| RSpec/ExpectActual | 7 | Move expectations out of `let`/`subject` |
| RSpec/NoExpectationExample | 2 | Add expectations or use `pending` |
| RSpec/ExpectInLet | 1 | Move expectation out of `let` |
| RSpec/LeakyLocalVariable | 1 | Use `let` instead of local assignment |
| RSpec/BeforeAfterAll | 1 | Evaluate if `before(:all)` can be `before(:each)` |

## Verification

- `bundle exec rubocop --only RSpec` shows significantly reduced count
- `bundle exec rspec` passes
