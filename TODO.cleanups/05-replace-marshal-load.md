# 05 — Replace Marshal.load with safe deserialization (4 offenses)

## Problem

`Marshal.load` is flagged by `Security/MarshalLoad` because deserializing untrusted data can lead to remote code execution. The gem uses it in the `.lur` package format (a ZIP file containing serialized Ruby objects).

## Affected files

```ruby
# lib/lutaml/uml_repository/package_loader.rb:194
Marshal.load(entry.get_input_stream.read)

# lib/lutaml/uml_repository/package_loader.rb:210
Marshal.load(entry.get_input_stream.read)

# spec/lutaml/uml_repository/package_exporter_spec.rb:141
expect { Marshal.load(serialized) }.not_to raise_error

# spec/lutaml/uml_repository/package_exporter_spec.rb:171
expect { Marshal.load(serialized) }.not_to raise_error
```

## Approach

**Option A: Switch to JSON serialization** — Replace `Marshal.dump`/`Marshal.load` with `JSON.generate`/`JSON.parse` in `PackageExporter` and `PackageLoader`. This is safe but requires models to be JSON-serializable.

**Option B: Use YAML with permitted classes** — `YAML.safe_load` with an explicit allowlist of classes. More flexible but still requires maintaining the class list.

**Option C: Keep Marshal but document the trust boundary** — If `.lur` files are only ever created by the gem itself (trusted), the risk is mitigated. Add a clear comment at the load site and suppress the cop with justification.

**Recommended**: Option A if feasible (cleanest), Option C as a minimal fix.

## Verification

- `bundle exec rubocop --only Security/MarshalLoad` shows 0 offenses
- `.lur` package round-trip (export → load) works correctly
- `bundle exec rspec` passes
