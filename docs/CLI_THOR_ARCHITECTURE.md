# LutaML CLI Thor Architecture

## Principle

**exe/lutaml must DIRECTLY use Thor with ZERO custom logic**

Thor provides:
- Help system (don't override)
- Subcommand routing
- Error handling

## Correct Structure

### exe/lutaml (Simple Thor Entry Point)

```ruby
#!/usr/bin/env ruby
require "pathname"
bin_file = Pathname.new(__FILE__).realpath
$:.unshift File.expand_path("../../lib", bin_file)

require "lutaml/cli"

# DIRECT Thor invocation - no custom routing
Lutaml::CLI.start(ARGV)
```

### lib/lutaml/cli.rb (Thor Root with Subcommands)

```ruby
module Lutaml
  class CLI < Thor
    desc "uml SUBCOMMAND", "UML repository operations (XMI/QEA/LUR files)"
    subcommand "uml", Cli::UmlCommands

    desc "lml SUBCOMMAND", "LutaML textual notation operations"
    subcommand "lml", Cli::LmlCommands

    # Deprecated alias
    desc "xmi SUBCOMMAND", "UML repository operations (⚠ deprecated, use 'uml')"
    subcommand "xmi", Cli::UmlCommands
  end
end
```

### Command Structure

```
lutaml
├── uml          (UML repository operations: QEA, XMI, LUR files)
│   ├── build     - Build LUR from XMI/QEA
│   ├── validate  - Validate QEA or LUR file
│   ├── info      - Show package metadata
│   ├── ls        - List elements
│   ├── inspect   - Show element details
│   ├── tree      - Package hierarchy
│   ├── stats     - Statistics
│   ├── search    - Full-text search
│   ├── find      - Criteria search
│   ├── export    - Export data
│   ├── docs      - Generate docs
│   ├── serve     - Web UI
│   ├── repl      - Interactive shell
│   └── verify    - XMI/QEA equivalence
│
├── lml          (LutaML textual notation operations)
│   ├── generate  - Generate diagram from .lutaml DSL file
│   └── validate  - Validate DSL syntax
│
└── xmi          (Deprecated alias for 'uml')
```

## Usage Examples

```bash
# UML operations (EXPLICIT - no shortcuts)
lutaml uml build model.qea
lutaml uml validate model.qea
lutaml uml validate model.lur
lutaml uml info model.lur

# LutaML textual notation operations
lutaml lml generate model.lutaml -o diagram.png
lutaml lml validate model.lutaml

# Help (Thor provides automatically)
lutaml help
lutaml uml help
lutaml lml help

# What does NOT work (by design)
lutaml build model.qea          # ✗ Error: unknown command
lutaml validate model.qea       # ✗ Error: unknown command
lutaml model.lutaml             # ✗ Error: unknown command
```

## Why This Is Correct

1. **MECE**: Each subcommand has distinct responsibility
   - `uml` = repository operations on UML files
   - `lml` = LutaML textual notation operations

2. **No Shortcuts**: Explicit commands only
   - lutaml has multiple model types (UML, EXPRESS, XSD, SysML)
   - Shortcuts would be ambiguous
   - Users must specify which model type

3. **Consistent Thor**: Single framework throughout
   - No mixing with CommandLine class
   - Thor provides help, error handling, aliases
   - All commands follow same patterns

4. **Extensible**: Easy to add more subcommands
   - `lutaml express` for EXPRESS schema
   - `lutaml xsd` for XSD schema
   - Each with their own command sets

## Implementation

Done in latest task:
- ✅ Removed shorthand routing from exe/lutaml
- ✅ exe/lutaml directly calls Thor
- ✅ LmlCommands created as Thor subcommand
- ✅ Migrated DSL functionality from CommandLine
- ✅ All CLI uses Thor consistently