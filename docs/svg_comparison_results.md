# SVG Comparison Testing Results

This document describes the SVG accuracy testing framework, known differences between LutaML-generated and Enterprise Architect (EA) reference SVG exports, acceptable tolerance levels, and guidelines for interpreting test results.

## Overview

The SVG accuracy test suite (`spec/lutaml/ea/diagram/svg_accuracy_spec.rb`) validates that diagram generation produces output matching or acceptably similar to EA's native SVG export. This ensures visual fidelity when converting UML diagrams from QEA/XMI to SVG format.

## Test Categories

### 1. Structure Comparison

**Purpose**: Validates that the generated SVG contains the same types and counts of elements as the EA reference.

**What is tested**:
- Element types (svg, g, rect, text, path, etc.)
- Element counts by type
- Overall document structure

**Acceptable differences**:
- ±10% variance in total element count (EA may include additional metadata elements)
- Missing EA-specific metadata elements (comments, generator tags)
- Different ordering of elements (as long as visual result is equivalent)

**Tolerance levels**:
```ruby
# Element count variance
max_variance = 0.10  # 10%

# Structure match criteria
acceptable_if total_errors < 20
```

### 2. Coordinate Accuracy

**Purpose**: Ensures diagram elements are positioned correctly with pixel-level accuracy.

**What is tested**:
- X/Y coordinates of shapes (rect, circle, line)
- Width/height dimensions
- Path geometry (basic validation)

**Acceptable differences**:
- ±5px tolerance for all coordinate values
- Minor rounding differences (EA uses floats, may round differently)
- Sub-pixel variations due to different rendering engines

**Tolerance levels**:
```ruby
# Coordinate tolerance
COORDINATE_TOLERANCE = 5.0  # pixels

# Dimension tolerance
DIMENSION_TOLERANCE = 5.0   # pixels
```

**Why 5px?**
- Accounts for font rendering differences
- Handles minor layout engine variations
- Still maintains visual accuracy (5px is typically imperceptible at normal zoom)

### 3. Visual Similarity

**Purpose**: Validates overall visual appearance using pixel-by-pixel comparison.

**Requirements**:
- ImageMagick (`convert` command) or `rsvg-convert` must be available
- Tests are skipped if comparison tools are unavailable

**What is tested**:
- Pixel-by-pixel difference after converting to PNG
- Overall visual similarity score

**Acceptable differences**:
- ≥95% similarity threshold
- Minor anti-aliasing differences
- Font rendering variations between systems

**Tolerance levels**:
```ruby
# Visual similarity threshold
MIN_SIMILARITY = 0.95  # 95%

# Calculation
similarity = 1.0 - (diff_pixels / total_pixels)
```

### 4. Content Accuracy

**Purpose**: Validates that text labels, class names, and other content are preserved.

**What is tested**:
- Text element content
- Label completeness
- Stereotype and tagged value text

**Acceptable differences**:
- ±20% variance in text element count (EA may include additional labels)
- Different text positioning (as long as within coordinate tolerance)
- Re-ordered text elements

**Tolerance levels**:
```ruby
# Text content variance
max_missing = 0.20  # 20% of reference texts
```

### 5. Styling Preservation

**Purpose**: Ensures visual styling (colors, fonts, strokes) is maintained.

**What is tested**:
- Presence of style attributes
- Fill and stroke properties
- Font specifications

**Acceptable differences**:
- ±30% variance in styled element count
- Different CSS class names (as long as visual result is the same)
- Inline styles vs. CSS classes (both acceptable)

**Tolerance levels**:
```ruby
# Styling element variance
max_variance = 0.30  # 30%
```

## Known Acceptable Differences

### 1. EA-Specific Metadata

**What**: EA includes metadata elements that LutaML does not generate:
- XML comments with EA version info
- Generator meta tags
- EA-specific element IDs
- Internal EA styling classes

**Why acceptable**: These elements do not affect visual rendering.

**Example**:
```xml
<!-- EA reference includes: -->
<!-- Created with Enterprise Architect 15.2 -->
<meta name="generator" content="Enterprise Architect" />

<!-- LutaML does not include these -->
```

### 2. Element ID Generation

**What**: EA generates specific IDs for elements; LutaML may use different IDs or no IDs.

**Why acceptable**: IDs are for internal reference only, do not affect rendering.

**Example**:
```xml
<!-- EA: -->
<rect id="EAID_123ABC" ... />

<!-- LutaML: -->
<rect id="rect-1" ... />  <!-- or no ID -->
```

### 3. Number Formatting

**What**: Floating-point coordinates may be formatted differently:
- EA: `123.456789`
- LutaML: `123.46` (rounded to 2 decimals)

**Why acceptable**: Sub-pixel precision beyond 2 decimals is visually imperceptible.

### 4. Path Simplification

**What**: LutaML may simplify paths with redundant waypoints.

**Why acceptable**: Simplified paths produce identical visual output with less data.

**Example**:
```xml
<!-- EA might use: -->
<path d="M 10,20 L 10,20 L 30,40" />

<!-- LutaML simplifies to: -->
<path d="M 10,20 L 30,40" />
```

### 5. Style Specification Method

**What**: Styles can be specified via:
- Inline `style` attributes
- Individual attributes (`fill`, `stroke`)
- CSS classes

**Why acceptable**: All methods produce identical visual results.

## Known Unacceptable Differences

These differences indicate test failures that must be fixed:

### 1. Missing Elements

**Problem**: Generated SVG lacks shapes present in EA reference.

**Severity**: CRITICAL

**Action**: Fix element rendering logic.

### 2. Large Coordinate Offsets

**Problem**: Elements positioned >5px away from expected location.

**Severity**: HIGH

**Action**: Review layout engine calculations.

### 3. Incorrect Dimensions

**Problem**: Element sizes differ by >5px from EA reference.

**Severity**: HIGH

**Action**: Fix size calculation in renderers.

### 4. Missing Text Content

**Problem**: >20% of text elements are missing or incorrect.

**Severity**: HIGH

**Action**: Fix text rendering and label extraction.

### 5. Low Visual Similarity

**Problem**: Pixel comparison shows <95% similarity.

**Severity**: MEDIUM (investigate cause)

**Action**: Identify specific visual differences and fix rendering.

## Interpreting Test Results

### All Tests Passing

✅ **Status**: Production ready
- Structure matches EA output
- Coordinates are accurate
- Visual appearance is equivalent

### Pending Tests (No Reference SVGs)

⏸️ **Status**: Awaiting reference files
- Tests are skipped until EA reference SVGs are provided
- See `spec/fixtures/ea_svg_references/README.md` for instructions

**Action**: Export reference SVGs from EA and add to fixtures directory.

### Structure Mismatches

⚠️ **Investigate when**:
- Missing >10% of elements
- Extra >20% unexpected elements
- Missing critical element types (rect, text, path)

**Debug steps**:
1. Review structure difference report in test output
2. Compare generated vs. reference element counts
3. Check diagram data completeness
4. Verify renderer implementations

### Coordinate Failures

⚠️ **Investigate when**:
- >10% of coordinates exceed 5px tolerance
- Systematic offset (all elements shifted)
- Dimensions incorrect

**Debug steps**:
1. Review coordinate difference report
2. Check layout engine coordinate transformations
3. Verify EA coordinate system understanding
4. Test with simpler diagrams

### Visual Similarity Failures

⚠️ **Investigate when**:
- Similarity <95%
- Large pixel differences in specific areas

**Debug steps**:
1. Generate diff image (`compare` command output)
2. Identify specific visual discrepancies
3. Check font availability on system
4. Verify color and style accuracy

## Test Execution

### Running Full Suite

```bash
bundle exec rspec spec/lutaml/ea/diagram/svg_accuracy_spec.rb
```

### Running Specific Test Categories

```bash
# Structure comparison only
bundle exec rspec spec/lutaml/ea/diagram/svg_accuracy_spec.rb -e "structure comparison"

# Coordinate accuracy only
bundle exec rspec spec/lutaml/ea/diagram/svg_accuracy_spec.rb -e "coordinate accuracy"

# Visual similarity only (requires ImageMagick)
bundle exec rspec spec/lutaml/ea/diagram/svg_accuracy_spec.rb -e "visual similarity"
```

### Running for Specific Diagrams

```bash
# Test only "TestSchema" diagram
bundle exec rspec spec/lutaml/ea/diagram/svg_accuracy_spec.rb -e "TestSchema"
```

## Adding Reference SVGs

To enable full comparison testing:

1. Open `.qea` file in Enterprise Architect
2. Navigate to diagram
3. Export to SVG: Right-click → "Save Diagram as Image" → SVG format
4. Save to `spec/fixtures/ea_svg_references/` with diagram name as filename
5. Run tests - pending tests will now execute

See `spec/fixtures/ea_svg_references/README.md` for detailed instructions.

## Continuous Integration

Tests are designed to be CI-friendly:

- **Without reference SVGs**: Tests are skipped (not failures)
- **With reference SVGs**: Full validation runs
- **On systems lacking ImageMagick**: Visual comparison skipped

This allows CI to pass even without reference files, while providing full validation when references are available.

### CI Configuration Example

```yaml
# .github/workflows/test.yml
- name: Run SVG Accuracy Tests
  run: bundle exec rspec spec/lutaml/ea/diagram/svg_accuracy_spec.rb
  continue-on-error: true  # Don't fail build on pending tests
```

## Troubleshooting

### "Visual comparison tools not available"

**Problem**: ImageMagick or rsvg-convert not installed.

**Solution**:
```bash
# macOS
brew install imagemagick librsvg

# Ubuntu
apt-get install imagemagick librsvg2-bin
```

### "Diagram has no rendering data"

**Problem**: LUR file contains diagram metadata but no positioning information.

**Solution**: This is expected for some diagrams. Ensure source QEA file has complete diagram data.

### "Reference SVG not available"

**Problem**: No EA reference SVG exists for comparison.

**Solution**: Export reference SVG from EA (see instructions above).

### High Failure Rate

**Problem**: >50% of tests failing.

**Debug checklist**:
1. Verify test.lur is up-to-date
2. Check EA reference SVGs are from same model version
3. Review recent changes to rendering code
4. Run in isolation to eliminate environmental factors

## Summary

The SVG accuracy testing framework provides comprehensive validation of diagram generation quality. With appropriate tolerance levels and clear guidelines for acceptable differences, it ensures LutaML produces reliable, high-fidelity SVG output matching EA's native export capabilities.

**Key Points**:
- Tests are designed to be practical (reasonable tolerances)
- Pending tests don't block CI (opt-in validation)
- Clear distinction between acceptable and unacceptable differences
- Comprehensive debugging guidance
- Ready for production use