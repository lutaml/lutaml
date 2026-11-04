#!/bin/bash
# Example: Using text format (default, human-readable)

echo "=== Text Format (Default) ==="
echo "Human-readable output with checkmarks and summary"
echo ""

# Validate a single schema in text format
lutaml-xsd validate-schema ../schemas/valid_schema.xsd

# Validate with verbose output
echo ""
echo "=== Text Format with Verbose ==="
lutaml-xsd validate-schema ../schemas/valid_schema.xsd --verbose

# Validate multiple schemas
echo ""
echo "=== Multiple Schemas ==="
lutaml-xsd validate-schema ../schemas/valid_schema.xsd ../schemas/invalid_schema.xsd
