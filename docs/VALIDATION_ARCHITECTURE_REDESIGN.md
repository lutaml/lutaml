# Validation Architecture Redesign

## Core Problem

**Current validators like "ClassValidator" treat packages/classes/attributes as cross-cutting concerns. This is WRONG.**

A package is not a cross-cut. A class is not a cross-cut. An attribute is not a cross-cut. They are part of a hierarchical UML tree structure.

## Correct Two-Phase Validation Architecture

### Phase 1: QEA Database Validation

**What**: Validate raw EA database integrity BEFORE transformation
**When**: During `Lutaml::Qea.parse()` after loading database
**Validates**: Referential integrity of EA data model

```
Database (SQLite)
    ↓
Load all tables into collections
    ↓
QEA Database Validation (Phase 1)
  ├── ReferentialIntegrityValidator
  │   • Foreign keys valid (Package_ID exists, Object_ID exists, etc.)
  │   • No dangling references
  │   • Proper type casting based on Object_Type
  │
  ├── OrphanValidator
  │   • Objects with invalid Package_ID
  │   • Attributes with invalid Object_ID
  │   • Operations with invalid Object_ID
  │
  └── CircularReferenceValidator
      • Circular packages (Parent_ID loops)
      • Circular generalizations
```

**Key Principle**: Validate EA database schema integrity, NOT UML semantics

### Phase 2: UML Document Validation

**What**: Validate transformed UML tree structure
**When**: After transformation to `Lutaml::Uml::Document`
**Validates**: UML model semantics and completeness

```
Transformation
  ├── Class (Object_Type="Class") → Lutaml::Uml::Class
  ├── Note (Object_Type="Note") → Documentation (attached to parent)
  ├── Package (Object_Type="Package") → Lutaml::Uml::Package
  ├── Enumeration → Lutaml::Uml::Enum
  └── DataType → Lutaml::Uml::DataType
    ↓
Lutaml::Uml::Document (tree structure)
  ├── packages[]
  │   └── classes[]
  │       ├── attributes[]
  │       └── operations[]
  ├── associations[]
  └── diagrams[]
    ↓
UML Document Validation (Phase 2)
  ├── DocumentStructureValidator
  │   • Package tree is valid
  │   • No empty required collections
  │   • Proper nesting
  │
  ├── ReferenceValidator
  │   • Type references resolve
  │   • Association ends exist
  │   • Generalization parents exist
  │
  └── SemanticValidator
      • UML naming conventions
      • Multiplicity constraints
      • Abstract class rules
```

**Key Principle**: Validate UML tree structure, NOT EA database

## Correct Object Type Handling

### EA Object Types Must Be Cast

**Database Layer (QEA):**
```
t_object.Object_Type:
  - "Class" → will become Lutaml::Uml::Class
  - "Note" → content extracted, attached to parent
  - "Package" → will become Lutaml::Uml::Package
  - "Interface" → will become Lutaml::Uml::Class (with stereotype)
  - "Enumeration" → will become Lutaml::Uml::Enum
  - "DataType" → will become Lutaml::Uml::DataType
  - "Text" → documentation element
  - "Boundary" → diagram element only
```

**Transformation Layer:**
```ruby
# Cast based on Object_Type
case ea_object.object_type
when "Class", "Interface"
  ClassTransformer.transform(ea_object) → Lutaml::Uml::Class
when "Note", "Text"
  Extract content, attach to linked_object
when "Enumeration"
  EnumTransformer.transform(ea_object) → Lutaml::Uml::Enum
when "Package"
  PackageTransformer.transform(ea_object) → Lutaml::Uml::Package
else
  Skip or warn
end
```

## Redesigned Validator Structure

### QEA Database Validators (Phase 1)

Located in `lib/lutaml/qea/validation/database/`:

```ruby
# Validates EA database before transformation
class ReferentialIntegrityValidator
  def validate
    validate_package_references
    validate_object_references
    validate_attribute_references
    validate_connector_references
    validate_operation_references
  end

  private

  def validate_package_references
    database.packages.each do |pkg|
      next if pkg.root?

      unless parent_package_exists?(pkg.parent_id)
        result.add_error(
          category: :missing_reference,
          entity_type: :ea_package,
          entity_id: pkg.package_id,
          message: "Parent package #{pkg.parent_id} does not exist"
        )
      end
    end
  end

  def validate_object_references
    database.objects.all.each do |obj|
      unless package_exists?(obj.package_id)
        result.add_error(
          category: :missing_reference,
          entity_type: "ea_#{obj.object_type.downcase}",
          entity_id: obj.object_id,
          message: "Package #{obj.package_id} does not exist"
        )
      end
    end
  end
end
```

### UML Document Validators (Phase 2)

Located in `lib/lutaml/uml/validation/`:

```ruby
# Validates UML Document tree structure
class DocumentStructureValidator
  def validate
    validate_package_tree(document.packages)
    validate_class_integrity
    validate_association_endpoints
  end

  private

  def validate_package_tree(packages)
    packages.each do |package|
      # Validate package has valid name
      if package.name.nil? || package.name.empty?
        result.add_warning(
          category: :missing_required,
          entity_type: :package,
          qualified_name: package_qualified_name(package),
          message: "Package has no name"
        )
      end

      # Recursively validate nested packages
      validate_package_tree(package.packages) if package.packages&.any?

      # Validate classes within package
      validate_package_classes(package)
    end
  end

  def validate_package_classes(package)
    package.classes&.each do |klass|
      # Check for duplicate names within same package
      duplicates = package.classes.select { |c| c.name == klass.name }
      if duplicates.size > 1
        result.add_warning(
          category: :duplicate,
          entity_type: :class,
          qualified_name: "#{package_path(package)}::#{klass.name}",
          message: "Duplicate class name in package"
        )
      end
    end
  end
end
```

## Implementation Phases

### Phase 1: Refactor ValidationEngine (CRITICAL)

1. Rename current validators to `QeaDatabase*Validator`
2. Move to `lib/lutaml/qea/validation/database/`
3. Create new UML validators in `lib/lutaml/uml/validation/`
4. Update ValidationEngine to run both phases:
   ```ruby
   def validate
     # Phase 1: QEA database integrity
     qea_result = validate_qea_database(database)

     # Phase 2: UML document structure (only if phase 1 passes or non-critical)
     uml_result = validate_uml_document(document)

     # Merge results
     qea_result.merge!(uml_result)
   end
   ```

### Phase 2: Extract Proper Entities

Update ValidationEngine.build_context to extract from document:
```ruby
context[:packages] = extract_all_packages(document)
context[:classes] = extract_all_classes(document)
context[:enums] = extract_all_enums(document)
```

NOT from raw database.

### Phase 3: Note Handling

Implement NoteTransformer to:
1. Extract note content
2. Find linked entity
3. Attach as documentation/definition
4. NOT add to document.classes

## Success Criteria

1. ✅ Notes don't appear in class validation
2. ✅ Note content IS attached to target entities
3. ✅ QEA referential integrity validated
4. ✅ UML document structure validated
5. ✅ Two-phase validation clearly separated
6. ✅ MECE principles followed

## Migration Path

1. Document current validators as "legacy QEA validators"
2. Implement new two-phase architecture alongside
3. Gradually migrate tests
4. Remove legacy validators once new system proven