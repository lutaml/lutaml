#!/bin/bash
# Validate a single XSD schema file

echo "=== Single File Validation ==="
echo

# Validate XSD 1.0 schema
echo "Validating XSD 1.0 schema..."
bundle exec lutaml-xsd validate-schema ../schemas/valid_xsd_1_0.xsd

if [ $? -eq 0 ]; then
  echo "✓ Validation passed"
else
  echo "✗ Validation failed"
  exit 1
fi

echo
echo "Validating XSD 1.1 schema..."
bundle exec lutaml-xsd validate-schema ../schemas/valid_xsd_1_1_assertions.xsd --version 1.1

if [ $? -eq 0 ]; then
  echo "✓ Validation passed"
else
  echo "✗ Validation failed"
  exit 1
fi
