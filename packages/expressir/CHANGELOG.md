# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes

#### Repository Structure Change

The `Repository` class now uses a `files` attribute containing `ExpFile` objects instead of a direct `schemas` attribute.

**Old structure:**
```ruby
repository = Expressir::Model::Repository.new
repository.schemas << schema1
repository.schemas << schema2
```

**New structure:**
```ruby
repository = Expressir::Model::Repository.new
repository.add_schema(schema1)
repository.add_schema(schema2)

# Or with files:
exp_file = Expressir::Express::Parser.from_file("schema.exp")
repository.files << exp_file
```

#### ExpFile Model Introduced

A new `ExpFile` class represents a single EXPRESS file with its own preamble remarks and schemas:

```ruby
# ExpFile has:
# - path: the file path
# - schemas: array of schemas in the file
# - untagged_remarks: file-level preamble remarks

exp_file = Expressir::Model::ExpFile.new(path: "my_schema.exp")
exp_file.schemas = [schema]
exp_file.untagged_remarks = [remark_info]
```

#### Parser Return Type Changed

`Expressir::Express::Parser.from_file` now returns an `ExpFile` instead of a `Repository`:

```ruby
# Old: returned Repository
# New: returns ExpFile
exp_file = Expressir::Express::Parser.from_file("schema.exp")
exp_file.path   # => "schema.exp"
exp_file.schemas # => [#<Expressir::Model::Declarations::Schema...>]
```

#### Error Class Changes

- `InvalidSchemaManifestError` → Use `ManifestValidationError` instead
- `Expressir::Express::CacheVersionMismatchError` → Use `Expressir::Express::Error::CacheVersionMismatchError`

#### RemarkInfo Required

Remark formatters now require `RemarkInfo` objects instead of strings:

```ruby
# Old:
formatter.format_preamble_remark("This is a remark")

# New:
remark = Expressir::Model::RemarkInfo.new(text: "This is a remark")
formatter.format_preamble_remark(remark)
```

### Added

- `Expressir::Model::ExpFile` class for representing EXPRESS files
- `Expressir::Model::Concerns` module with marker modules for O(1) type checking:
  - `HasRemarkItems` - types that can have remark_items children
  - `ScopeContainer` - types that can contain declarations
  - `HasInformalPropositions` - types supporting informal propositions
  - `HasWhereRules` - types supporting where rules
- `Repository#add_schema(schema)` method for adding schemas
- `Repository#files` attribute for storing ExpFile objects
- `Package::Builder#normalize_repository` ensures proper serialization format

### Changed

- `Repository#schemas` now returns schemas from both `files` and internal storage
- `Parser.from_file` returns `ExpFile` instead of `Repository`
- `Parser.from_files` creates `Repository` with `ExpFile` objects
- `Parser.from_exp` returns `ExpFile` instead of `Repository`
- `format_repository` in formatters handles both file-based and direct schemas
- Preamble remarks now attach to `ExpFile` instead of first `Schema`

### Removed

- All backward compatibility code for legacy serialized data
- `Repository#schemas=` writer (use `add_schema` instead)
- Legacy string handling in remark formatters
- `InvalidSchemaManifestError` alias (use `ManifestValidationError`)
- Legacy `@schemas` attribute migration in Repository
- Array-based type checking in `remark_attacher.rb` (replaced with module markers)

### Migration Guide

#### Updating Code That Uses Repository

```ruby
# Before:
repo = Expressir::Model::Repository.new
repo.schemas << schema

# After:
repo = Expressir::Model::Repository.new
repo.add_schema(schema)
```

#### Updating Code That Parses Files

```ruby
# Before:
repo = Expressir::Express::Parser.from_file("schema.exp")
schema = repo.schemas.first

# After:
exp_file = Expressir::Express::Parser.from_file("schema.exp")
schema = exp_file.schemas.first

# Or wrap in repository:
repo = Expressir::Model::Repository.new
repo.files << Expressir::Express::Parser.from_file("schema.exp")
```

#### Updating Serialized Packages

Old `.ler` packages need to be regenerated with the new format:

```ruby
# Load old package (will fail with new code)
# repo = Expressir::Model::Repository.from_package("old.ler")

# Regenerate by parsing original EXPRESS files
exp_file = Expressir::Express::Parser.from_file("schema.exp")
repo = Expressir::Model::Repository.new
repo.files << exp_file
repo.export_to_package("new.ler", name: "My Package", version: "1.0.0")
```

## [2.2.1] - 2024-03-14

### Changed

- Refactored `require` to `autoload` pattern for better load performance
- Updated error handling to use error classes instead of `abort`
