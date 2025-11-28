# Note Object Architecture in EA to UML Transformation

## Problem Statement

Object ID 360 has `Object_Type="Note"` but appears in ClassValidator warnings:
```
⚠ class
  Duplicate class name '' in Conceptual Models::3D都市モデル::都市計画データ (package_id: 31)
  ID: 360
```

This indicates Notes are being incorrectly validated as Classes.

## EA Object Type Taxonomy

In Enterprise Architect, objects can have various types:

### UML Model Elements (should be transformed to UML entities)
- **Class** → [`Lutaml::Uml::Class`](../lib/lutaml/uml/top_element.rb)
- **Interface** → [`Lutaml::Uml::Class`](../lib/lutaml/uml/top_element.rb) (with stereotype)
- **Enumeration** → [`Lutaml::Uml::Enum`](../lib/lutaml/uml/enum.rb)
- **DataType** → [`Lutaml::Uml::DataType`](../lib/lutaml/uml/data_type.rb)
- **Package** → [`Lutaml::Uml::Package`](../lib/lutaml/uml/package.rb)
- **Component** → [`Lutaml::Uml::Class`](../lib/lutaml/uml/top_element.rb) (with stereotype)

### Documentation Elements (content only, not entities)
- **Note** → Content extracted and attached to target entities

## Note Objects: Special Handling Required

### What Notes Are

Notes in EA are documentation attachments that:
1. Have their own `object_id` in `t_object` table
2. Contain text content in the `note` field
3. Are **linked** to other entities (classes, packages, attributes, etc.)
4. Appear in diagrams as visual annotations

### What Notes Are NOT

Notes are **NOT**:
- UML Classes
- UML Packages
- UML Data Types
- Any standalone UML entity

### How Notes Should Be Handled

```
┌─────────────────────────────────────────────────────────┐
│ Transform Pipeline                                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  EA Database Objects                                     │
│  ├── Class (ID: 100) ──────────┐                        │
│  ├── Package (ID: 31)          │                        │
│  ├── Note (ID: 360) ───────────┼─> Extract content      │
│  └── Interface (ID: 200)       │   Attach to target     │
│                                 │                        │
│  Transform Step                 │                        │
│  ├── ClassTransformer ──────────┘                        │
│  │   • Filters: uml_class? || interface?                │
│  │   • Result: Class, Interface objects only            │
│  │                                                       │
│  ├── PackageTransformer                                 │
│  │   • Filters: package?                                │
│  │   • Attaches Note content to packages                │
│  │                                                       │
│  └── NoteTransformer (if needed)                        │
│      • Processes Note objects                           │
│      • Extracts content                                 │
│      • Links to target entities                         │
│                                                          │
│  UML Document                                            │
│  ├── Package ← (may have notes attached)                │
│  │   └── Classes ← (may have notes attached)            │
│  ├── Associations                                        │
│  └── Diagrams ← (may reference notes visually)          │
│                                                          │
│  ✓ Notes are NOT in document.classes                    │
│  ✓ Note content IS in entity.definition                 │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Current Bug: Validation Architecture

### Problem Flow

```
Database.objects.all (ALL types including Notes)
           ↓
ValidationEngine.build_context
  context[:objects] = database.objects.all  ← Includes Notes!
           ↓
ClassValidator.objects
  @objects = context[:objects]  ← Still includes Notes!
           ↓
ClassValidator.validate_duplicate_names
  Validates ALL objects as if they were classes ← BUG!
```

### Why This is Wrong

1. **Separation of Concerns Violated**
   - Validator receives raw database objects
   - Should receive transformed UML entities

2. **Type Safety Broken**
   - ClassValidator validates any object type
   - Should only validate UML Classes

3. **Architecture Mismatch**
   - Transformation filters correctly
   - Validation doesn't respect filtering

## Correct Architecture

### Option 1: Filter in Validator (CURRENT FIX)

```ruby
# lib/lutaml/qea/validation/class_validator.rb
def objects
  @objects ||= begin
    all_objects = context[:objects] || []
    # Only validate UML Classes and Interfaces
    all_objects.select { |obj| obj.uml_class? || obj.interface? }
  end
end
```

**Pros:**
- Quick fix
- Defensive programming
- Handles edge cases

**Cons:**
- Validation still receives incorrect data
- Not MECE (filtering in multiple places)
- Band-aid on architectural issue

### Option 2: Validate Document Entities (PROPER SOLUTION)

```ruby
# lib/lutaml/qea/validation/validation_engine.rb
def build_context
  context = {
    document: @document,
    database: @database,  # For reference integrity checks only
    options: @options,
  }

  # Extract entities from TRANSFORMED document, not raw database
  if @document
    context[:packages] = extract_all_packages(@document)
    context[:classes] = extract_all_classes(@document)
    context[:enumerations] = extract_all_enums(@document)
    context[:data_types] = extract_all_data_types(@document)
    context[:associations] = @document.associations || []
    context[:diagrams] = extract_all_diagrams(@document)
  end

  # Keep database for referential integrity checks
  # but DON'T use database.objects in entity validators!

  context
end

# lib/lutaml/qea/validation/class_validator.rb
def objects
  @objects ||= context[:classes] || []  # Already filtered!
end
```

**Pros:**
- MECE architecture
- Single source of truth (document)
- Type-safe (only UML entities)
- Validates what was actually transformed

**Cons:**
- Requires refactoring all validators
- More complex initial implementation

## Recommended Solution

**Hybrid Approach:**

1. **Short-term:** Apply defensive filter in ClassValidator (already done)
2. **Long-term:** Refactor ValidationEngine to use document entities

### Phase 1: Defensive Filtering (COMPLETED)
```ruby
# Keep invalid data out of validators
def objects
  all_objects = context[:objects] || []
  all_objects.select { |obj| obj.uml_class? || obj.interface? }
end
```

### Phase 2: Context Refactoring (TODO)
```ruby
# Provide correct data to validators
context[:classes] = extract_all_classes(document)
context[:packages] = extract_all_packages(document)
# etc.
```

### Phase 3: Database for Integrity Only (TODO)
```ruby
# Use database only for cross-referencing
# Not as primary validation source
context[:database] = database  # Reference only
```

## Impact on Other Validators

Each validator must handle object types correctly:

### PackageValidator
- Should validate `Package` objects only
- ✓ Already correct (uses `context[:packages]`)

### AttributeValidator
- Should validate attributes within classes
- Access via `context[:classes]` not `context[:objects]`

### AssociationValidator
- Should validate associations between classes
- Already uses `context[:connectors]` correctly

### DiagramValidator
- Should validate diagram references
- May include Note objects in diagrams (visual only)
- Must distinguish between entity references and note references

## Testing Requirements

1. **Unit Test:** Note objects are filtered from ClassValidator
2. **Integration Test:** Notes don't appear in validation warnings
3. **Functional Test:** Note content IS attached to target entities
4. **Regression Test:** Existing validations still work

## References

- [`ea_object.rb`](../lib/lutaml/qea/models/ea_object.rb) - Object type predicates
- [`class_transformer.rb`](../lib/lutaml/qea/factory/class_transformer.rb) - Correct filtering
- [`validation_engine.rb`](../lib/lutaml/qea/validation/validation_engine.rb) - Context building
- [`class_validator.rb`](../lib/lutaml/qea/validation/class_validator.rb) - Validation logic