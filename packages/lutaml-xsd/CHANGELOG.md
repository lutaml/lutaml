## [Unreleased]

### Changed
- **BREAKING:** Removed `build from-config` command - use `pkg build CONFIG` instead
- CLI restructured with MECE command organization
- All package building now uses `pkg build CONFIG` syntax

### Added
- Package composition with conflict detection and resolution
  - Compose unified repositories from multiple LXR packages
  - Configurable conflict resolution strategies (keep, override, error)
  - Namespace URI remapping for avoiding conflicts
  - Schema filtering with glob patterns (exclude/include)
  - Priority-based package loading (lower number = higher priority)
  - Complete YAML configuration support via `base_packages`
  - Backward compatibility with legacy string array format
  - Comprehensive documentation in `docs/PACKAGE_COMPOSITION.adoc`
- `output_package` configuration field for specifying output path
  - Configuration-based output path specification
  - CLI `-o` flag overrides config value
  - Default behavior when neither specified
- CLI enhancements:
  - `pkg ls --show-tree` shows package hierarchy
  - `pkg inspect` displays base packages and mappings
  - Enhanced metadata display for composed packages
  - Human-readable file sizes in package listings
- Enhanced `SchemaRepository` with composition support
  - `normalize_base_packages_to_configs()` method for handling mixed formats
  - `load_base_packages_with_conflict_detection()` for conflict workflow
  - `load_package_with_filtering()` for schema filtering
  - `supports_conflict_detection?()` for auto-detection
  - `apply_namespace_remapping_to_schemas()` for URI transformations
- New model classes for package composition
  - `BasePackageConfig` - Configuration for individual packages with validation
  - `NamespaceUriRemapping` - Namespace transformation rules
  - `PackageSource` - Runtime wrapper for loaded packages
  - `Conflicts::NamespaceConflict` - Namespace URI conflict model
  - `Conflicts::TypeConflict` - Type name conflict model
  - `Conflicts::SchemaConflict` - Schema file conflict model with source tracking
  - `ConflictReport` - Comprehensive conflict reporting with serialization
- Service classes for conflict management
  - `PackageConflictDetector` - Detects all conflict types across packages
  - `PackageConflictResolver` - Applies resolution strategies with priority handling
- New error classes
  - `ValidationFailedError` - Configuration validation errors with details
  - `PackageMergeError` - Composition conflict errors with detailed reports
- Validation framework
  - `ValidationError` - Structured error objects with field/value/constraint
  - `ValidationResult` - Standardized validation result pattern with serialization

### Fixed
- SPA generation correctly displays all namespaces from composed packages
- Type resolution works seamlessly across composed packages
- Cross-package type linking functions properly

### Testing
- Added comprehensive test coverage for package composition features
- Added tests for `output_package` configuration field
- Added tests for CLI commands (`pkg ls`, `pkg inspect`, `pkg build`)
- Added tests for SPA generation with composed packages
- All tests passing (1732 examples, 0 failures in new code)

## [0.1.0] - 2024-11-18

- Initial release
