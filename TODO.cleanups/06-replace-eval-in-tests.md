# 06 — Replace eval in tests with StringIO redirection (3 Security/Eval + 2 Style/EvalWithLocation + 2 Style/DocumentDynamicEvalDefinition)

## Problem

`spec/lutaml/cli/uml/search_command_spec.rb` uses `eval` to redirect `$stdout`/`$stderr` for capturing output. This triggers 7 rubocop offenses across Security and Style cops.

## Affected code

```ruby
# spec/lutaml/cli/uml/search_command_spec.rb:61-65
old_stream = eval(stream_var.to_s)
eval("#{stream_var} = StringIO.new")
# ...
eval("#{stream_var} = old_stream") if defined?(old_stream) && old_stream
```

## Fix

Replace with a standard output capture pattern:

```ruby
# Use RSpec's built-in output matcher:
expect { command.run }.to output(/expected text/).to_stdout

# Or use a capture helper:
def capture_output
  old_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_stdout
end
```

No `eval` needed — just use `$stdout` directly instead of dynamically resolving the variable name.

## Verification

- `bundle exec rubocop --only Security/Eval,Style/EvalWithLocation,Style/DocumentDynamicEvalDefinition` shows 0 offenses
- `bundle exec rspec spec/lutaml/cli/uml/search_command_spec.rb` passes
