# 05 — Cache the `Class.new(Formatter) { include HyperlinkFormatter }` in `ModelElement#source` as a constant

**Priority:** P1 (wasteful per-call allocation)

## Problem

`lib/expressir/model/model_element.rb:100-105`:

```ruby
def source
  formatter = Class.new(Expressir::Express::Formatter) do
    include Expressir::Express::HyperlinkFormatter
  end
  formatter.format(self)
end
```

Every call to `source` on any model element allocates a fresh anonymous class,
runs the `self.included` hook, builds the `format_registry` hash, instantiates
the class, and formats the tree. The result is identical across calls.

`source` is a getter that may be invoked frequently during serialization and
inspection. Wasteful.

## Fix

Define a single named class once, e.g. `Expressir::Express::SourceFormatter`,
that subclasses `Formatter` and includes `HyperlinkFormatter`. `ModelElement#source`
instantiates it (cheap) instead of allocating a new class.

The class lives in `lib/expressir/express/source_formatter.rb` (autoloaded),
breaking the model→express dependency at the source-text level — but the model
already depends on express for serialization, so this just makes it explicit.

## Files affected

- `lib/expressir/model/model_element.rb` (use the constant)
- New file `lib/expressir/express/source_formatter.rb`
- `lib/expressir/express.rb` (add autoload)

## Acceptance

- `grep -n "Class.new" lib/expressir/model/model_element.rb` returns nothing.
- All model_element specs pass.
- `ModelElement#source` no longer allocates a class per call (benchmark optional).
