#!/bin/bash
# Validate schemas with verbose output

echo "=== Verbose Validation ==="
echo

echo "Validating with verbose output enabled..."
bundle exec lutaml-xsd validate-schema ../schemas/*.xsd --verbose

echo
echo "Exit code: $?"
