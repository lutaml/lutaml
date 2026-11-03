# LER (LutaML EXPRESS Repository) Examples

This directory contains example EXPRESS schemas and demonstration scripts for the LER package system.

## Files

### Schema Files
- **simple_schema.exp** - A simple example schema with products, types, and enumerations

### Example Scripts
- **../ler_build.rb** - Build LER package from schema
- **../ler_query.rb** - Query entities and types from package
- **../ler_stats.rb** - Get comprehensive statistics
- **../ler_cli.rb** - Demonstrate CLI commands

## Quick Start

### 1. Build the Package

```bash
ruby examples/ler_build.rb
```

This creates `examples/ler/simple_example.ler` containing:
- The parsed schema
- Pre-built indexes for fast queries
- Metadata and configuration

### 2. Query the Package

```bash
ruby examples/ler_query.rb
```

Demonstrates:
- Loading packages (<100ms)
- Finding specific entities
- Listing entities
- Finding types
- Filtering types by category

### 3. View Statistics

```bash
ruby examples/ler_stats.rb
```

Shows:
- Entity and type counts
- Distribution by schema
- Type categorization
- Interface relationships
- Validation results

### 4. Use CLI Commands

```bash
ruby examples/ler_cli.rb
```

Demonstrates all CLI commands:
- `expressir package info`
- `expressir entity find/list`
- `expressir type find/list`
- `expressir stats show`

## Direct CLI Usage

Once you've built the package, you can use these commands directly:

```bash
# Package information
bundle exec expressir package info examples/ler/simple_example.ler

# Find entity
bundle exec expressir entity find "simple_example.product" \
  --from examples/ler/simple_example.ler

# List all entities
bundle exec expressir entity list --from examples/ler/simple_example.ler

# List types by category
bundle exec expressir type list --from examples/ler/simple_example.ler \
  --category enumeration

# Show statistics
bundle exec expressir stats show examples/ler/simple_example.ler
```

## Creating Your Own Packages

To create a package from your schemas:

```ruby
require 'expressir'

# Option 1: From a single schema file (automatic dependency resolution)
repo = Expressir::Model::Repository.from_files(['your_schema.exp'])
repo.export_to_package('output.ler', name: 'My Package', version: '1.0')

# Option 2: Using CLI
# bundle exec expressir package build your_schema.exp output.ler \
#   --name "My Package" --version "1.0"
```

## Performance

LER packages provide significant performance benefits:
- **Loading**: <100ms (vs seconds of parsing)
- **Queries**: <1ms (pre-built indexes)
- **Distribution**: Single .ler file (vs multiple .exp files)