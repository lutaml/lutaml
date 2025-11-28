# EA SVG Reference Files

This directory contains SVG files exported directly from Enterprise Architect (EA) to serve as reference output for diagram generation accuracy testing.

## Purpose

These reference files are used to validate that LutaML's diagram generation produces output that matches (or is acceptably similar to) EA's native SVG export.

## How to Add Reference Files

1. Open your `.qea` file in Enterprise Architect
2. Navigate to each diagram you want to test
3. Export the diagram to SVG:
   - Right-click diagram → "Save Diagram as Image"
   - Select "SVG (Scalable Vector Graphics)" format
   - Save with descriptive filename matching diagram name
4. Copy the SVG file to this directory

## Naming Convention

Use the diagram name (sanitized) as the filename:
- Diagram "Test Model" → `Test_Model.svg`
- Diagram "TestSchema" → `TestSchema.svg`
- Replace spaces with underscores
- Remove special characters

## Current Test Fixtures

The following diagrams from `../test.lur` need EA reference SVGs:

1. **Test Model** (XMI ID: {F4C23F9E-DD74-4fed-B75D-AD3C6448BA24})
   - Type: Logical
   - Objects: 1
   - Links: 0
   - Expected filename: `Test_Model.svg`

2. **TestSchema** (XMI ID: {B58D1A53-E860-41a3-8352-11C274093E83})
   - Type: Logical
   - Objects: 8
   - Links: 1
   - Expected filename: `TestSchema.svg`

## Test Behavior

- If reference SVG exists: Full comparison test runs
- If reference SVG missing: Test is skipped with message
- Tests will pass once reference files are provided and validated

## EA Export Settings

For consistent results, use these EA export settings:
- Format: SVG (Scalable Vector Graphics)
- Include: All elements and connectors
- Text: Embedded (not outlined)
- Fonts: Calibri (or as configured in your profile)
- Colors: As displayed in EA
- Background: White (or as configured)

## Adding New Test Cases

When adding new `.qea` fixtures:
1. Document the diagrams in this README
2. Export reference SVGs from EA
3. Place them in this directory
4. Update the test suite if needed
