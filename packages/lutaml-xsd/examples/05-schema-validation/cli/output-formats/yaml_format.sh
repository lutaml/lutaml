#!/bin/bash
# Example: Using YAML format for CI/CD integration

echo "=== YAML Format (Machine-readable) ==="
echo "Human-friendly and perfect for CI/CD systems that prefer YAML"
echo ""

# Validate and output YAML
lutaml-xsd validate-schema ../schemas/valid_schema.xsd --format yaml

# Validate with verbose mode (includes detected versions)
echo ""
echo "=== YAML Format with Verbose ==="
lutaml-xsd validate-schema ../schemas/valid_schema.xsd --format yaml --verbose

# Example: Parse YAML output in a CI/CD script
echo ""
echo "=== CI/CD Integration Example ==="
echo "Parsing YAML output to determine exit code:"
RESULT=$(lutaml-xsd validate-schema ../schemas/valid_schema.xsd --format yam 2>&1)
INVALID_COUNT=$(echo "$RESULT" | yq eval '.summary.invalid' -)
echo "Invalid schemas: $INVALID_COUNT"
if [ "$INVALID_COUNT" -gt 0 ]; then
  echo "❌ Validation failed!"
  exit 1
else
  echo "✅ All schemas valid!"
fi
