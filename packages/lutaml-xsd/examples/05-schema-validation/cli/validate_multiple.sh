#!/bin/bash
# Validate multiple XSD schema files using glob patterns

echo "=== Multiple File Validation ==="
echo

# Validate all valid schemas
echo "Validating all valid schemas..."
bundle exec lutaml-xsd validate-schema ../schemas/valid_*.xsd

if [ $? -eq 0 ]; then
  echo "✓ All schemas passed validation"
else
  echo "✗ Some schemas failed validation"
  exit 1
fi

echo
echo "Attempting to validate invalid schemas (expecting failures)..."
bundle exec lutaml-xsd validate-schema ../schemas/invalid_*.xsd

if [ $? -ne 0 ]; then
  echo "✓ Invalid schemas correctly failed validation"
else
  echo "✗ Invalid schemas should have failed"
fi
