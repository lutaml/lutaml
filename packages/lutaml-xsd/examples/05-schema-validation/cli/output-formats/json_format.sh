#!/bin/bash
# Example: Using JSON format for CI/CD integration

echo "=== JSON Format (Machine-readable) ==="
echo "Perfect for CI/CD pipelines and automated processing"
echo ""

# Validate and output JSON
lutaml-xsd validate-schema ../schemas/valid_schema.xsd --format json

# Validate with verbose mode (includes detected versions)
echo ""
echo "=== JSON Format with Verbose ==="
lutaml-xsd validate-schema ../schemas/valid_schema.xsd --format json --verbose

# Example: Parse JSON output in a CI/CD script
echo ""
echo "=== CI/CD Integration Example ==="
echo "Parsing JSON output to determine exit code:"
RESULT=$(lutaml-xsd validate-schema ../schemas/valid_schema.xsd --format json 2>&1)
INVALID_COUNT=$(echo "$RESULT" | jq '.summary.invalid')
echo "Invalid schemas: $INVALID_COUNT"
if [ "$INVALID_COUNT" -gt 0 ]; then
  echo "❌ Validation failed!"
  exit 1
else
  echo "✅ All schemas valid!"
fi
