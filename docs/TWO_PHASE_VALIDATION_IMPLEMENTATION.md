# Two-Phase Validation Architecture Implementation

## Overview

This document describes the implementation of the two-phase validation architecture for the Lutaml QEA validation system.

## Architecture

The validation system now follows a clear two-phase approach:

### Phase 1: QEA Database Integrity Validation

Validates the EA database schema constraints at the raw database level:

- **ReferentialIntegrityValidator** (`lib/lutaml/qea/validation/database/referential_integrity_validator.rb`)
  - Validates foreign key relationships
  - Checks package parent references
  - Verifies object package references
  - Validates connector object references

- **OrphanValidator** (`lib/lutaml/qea/validation/database/orphan_validator.rb`)
  - Detects orphaned objects (invalid package references)
  - Finds orphaned attributes (missing parent objects)
  - Identifies orphaned operations (missing parent objects)
  - Reports unreferenced objects

- **CircularReferenceValidator** (`lib/lutaml/qea/validation/database/circular_reference_validator.rb`)
  - Detects circular package hierarchies
  - Finds circular generalization (inheritance) chains

### Phase 2: UML Tree Structure Validation

Validates the transformed UML document tree structure:

- **DocumentStructureValidator** (`lib/lutaml/uml/validation/document_structure_validator.rb`)
  - Validates package hierarchy nesting
  - Checks for duplicate names within same parent
  - Validates type references in attributes
  - Ensures proper collection types
  - Verifies required fields (names, etc.)

- **Entity Validators** (existing validators)
  - PackageValidator
  - ClassValidator
  - AttributeValidator
  - OperationValidator
  - AssociationValidator
  - DiagramValidator

## Directory Structure

```
lib/
├── lutaml/
│   ├── qea/
│   │   └── validation/
│   │       ├── database/                    # Phase 1: QEA Database Validators
│   │       │   ├── referential_integrity_validator.rb
│   │       │   ├── orphan_validator.rb
│   │       │   └── circular_reference_validator.rb
│   │       ├── validation_engine.rb         # Orchestrates two-phase validation
│   │       ├── base_validator.rb
│   │       ├── validation_result.rb
│   │       ├── validation_message.rb
│   │       ├── validator_registry.rb
│   │       ├── package_validator.rb         # Phase 2: UML Entity Validators
│   │       ├── class_validator.rb
│   │       ├── attribute_validator.rb
│   │       ├── operation_validator.rb
│   │       ├── association_validator.rb
│   │       └── diagram_validator.rb
│   └── uml/
│       └── validation/                      # Phase 2: UML Tree Validators
│           └── document_structure_validator.rb
```

## ValidationEngine Refactoring

The [`ValidationEngine`](lib/lutaml/qea/validation/validation_engine.rb) has been refactored to support two-phase validation:

### New Methods

#### `validate_qea_database(context, validators = nil)`

Executes Phase 1 validators that check EA database integrity:
- referential_integrity
- orphan
- circular_reference

#### `validate_uml_tree(context, validators = nil)`

Executes Phase 2 validators that check UML tree structure:
- document_structure
- package
- class
- attribute
- operation
- association
- diagram

#### `validate(validators: nil)`

Main entry point that orchestrates both phases:
1. Runs Phase 1 (QEA database validation)
2. Runs Phase 2 (UML tree validation)
3. Merges results from both phases
4. Applies filtering based on options

## Usage

```ruby
require 'lutaml/qea/validation/validation_engine'

# Create validation engine with document and database
engine = Lutaml::Qea::Validation::ValidationEngine.new(
  document,
  database: db
)

# Run full two-phase validation
result = engine.validate

# Or run specific validators only
result = engine.validate(validators: [:referential_integrity, :document_structure])

# Check results
puts result.summary
puts "Errors: #{result.errors.size}"
puts "Warnings: #{result.warnings.size}"
```

## Benefits

### 1. Clear Separation of Concerns

- **Phase 1** validates raw database integrity (EA schema level)
- **Phase 2** validates transformed UML semantics (model level)

### 2. Better Error Reporting

Errors are now categorized by validation phase, making it easier to identify:
- Database schema issues (Phase 1)
- UML model structure issues (Phase 2)

### 3. Extensibility

New validators can be easily added to either phase:
- Database validators go in `lib/lutaml/qea/validation/database/`
- UML validators go in `lib/lutaml/uml/validation/`

### 4. Performance

Validation can be run phase-by-phase or validator-by-validator for targeted checks.

## Testing

Run the test suite to verify the two-phase architecture:

```bash
bundle exec ruby test_validation_architecture.rb
```

Expected output:
```
✓ ValidationEngine loaded successfully
✓ Registered validators: referential_integrity, orphan, circular_reference,
  document_structure, package, class, attribute, operation, association, diagram
✓ Two-phase validation executed successfully
✓ All file structure checks passed
```

## Migration Notes

### For Existing Code

The existing validation API remains unchanged. Code using the ValidationEngine will automatically benefit from the two-phase architecture without any modifications.

### For New Validators

When creating new validators:

1. **Database-level validators** should extend `Lutaml::Qea::Validation::BaseValidator` and be placed in `lib/lutaml/qea/validation/database/`

2. **UML tree validators** should extend `Lutaml::Qea::Validation::BaseValidator` and be placed in `lib/lutaml/uml/validation/`

3. Register validators in the appropriate phase in [`ValidationEngine#setup_default_validators`](lib/lutaml/qea/validation/validation_engine.rb:105)

## Future Enhancements

### Potential Additions

1. **Phase 1 Enhancements**
   - Schema consistency validator
   - Data type validator
   - Constraint validator

2. **Phase 2 Enhancements**
   - Stereotype validator
   - Tagged value validator
   - OCL constraint validator

3. **Architecture**
   - Validation result caching
   - Incremental validation
   - Parallel validation execution

## References

- [VALIDATION_ARCHITECTURE_REDESIGN.md](VALIDATION_ARCHITECTURE_REDESIGN.md) - Original design document
- [QEA Database Analysis](../analyze_qea_structure.rb) - Database structure analysis script
- [Test Suite](../test_validation_architecture.rb) - Validation architecture tests