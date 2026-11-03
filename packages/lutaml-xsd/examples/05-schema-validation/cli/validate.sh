#!/bin/bash
# This script demonstrates schema validation using the CLI

set -e

echo "======================================================================"
echo "LutaML-XSD Schema Validation CLI Examples"
echo "======================================================================"

# Change to the schemas directory
cd "$(dirname "$0")/../schemas"

echo ""
echo "======================================================================" 
echo "Example 1: Validate a single schema file"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema valid_schema.xsd"
echo ""
lutaml-xsd validate-schema valid_schema.xsd
echo ""

echo "======================================================================"
echo "Example 2: Validate with specific version"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema --version 1.0 valid_schema.xsd"
echo ""
lutaml-xsd validate-schema --version 1.0 valid_schema.xsd
echo ""

echo "======================================================================"
echo "Example 3: Validate XSD 1.1 schema with XSD 1.1 validator"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema --version 1.1 xsd11_schema.xsd"
echo ""
lutaml-xsd validate-schema --version 1.1 xsd11_schema.xsd
echo ""

echo "======================================================================"
echo "Example 4: Validate XSD 1.1 schema with XSD 1.0 validator (should fail)"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema --version 1.0 xsd11_schema.xsd"
echo ""
if lutaml-xsd validate-schema --version 1.0 xsd11_schema.xsd 2>&1; then
  echo "Unexpected success!"
else
  echo "Expected failure: XSD 1.1 features detected"
fi
echo ""

echo "======================================================================"
echo "Example 5: Validate multiple schemas with glob pattern"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema valid_*.xsd"
echo ""
lutaml-xsd validate-schema valid_*.xsd
echo ""

echo "======================================================================"
echo "Example 6: Validate all schemas in directory"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema *.xsd"
echo ""
if lutaml-xsd validate-schema *.xsd 2>&1; then
  echo "All schemas valid!"
else
  echo "Some schemas failed validation (expected)"
fi
echo ""

echo "======================================================================"
echo "Example 7: Verbose output"
echo "======================================================================"
echo "Command: lutaml-xsd validate-schema --verbose valid_schema.xsd"
echo ""
lutaml-xsd validate-schema --verbose valid_schema.xsd
echo ""

echo "======================================================================"
echo "Example 8: Validate invalid schemas (demonstrate error reporting)"
echo "======================================================================"

echo ""
echo "8a. Wrong namespace:"
echo "Command: lutaml-xsd validate-schema invalid_wrong_namespace.xsd"
if lutaml-xsd validate-schema invalid_wrong_namespace.xsd 2>&1; then
  echo "Unexpected success!"
else
  echo "Expected failure"
fi

echo ""
echo "8b. Missing namespace:"
echo "Command: lutaml-xsd validate-schema invalid_no_namespace.xsd"
if lutaml-xsd validate-schema invalid_no_namespace.xsd 2>&1; then
  echo "Unexpected success!"
else
  echo "Expected failure"
fi

echo ""
echo "8c. Not a schema document:"
echo "Command: lutaml-xsd validate-schema invalid_non_schema.xsd"
if lutaml-xsd validate-schema invalid_non_schema.xsd 2>&1; then
  echo "Unexpected success!"
else
  echo "Expected failure"
fi

echo ""
echo "======================================================================"
echo "CLI Examples Complete!"
echo "======================================================================"