#!/bin/bash
# Simple Schemas Example - CLI
#
# This script demonstrates:
# - Building LXR packages using CLI
# - Searching for types with CLI commands
# - Resolving type references via CLI
# - Package inspection
#
# Usage:
#   bash examples/01-simple/cli/run.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$EXAMPLE_DIR/../.." && pwd)"
CONFIG_PATH="$EXAMPLE_DIR/config.yml"
OUTPUT_PATH="$EXAMPLE_DIR/simple.lxr"

cd "$PROJECT_ROOT"

echo "================================================================================"
echo "01-SIMPLE: CLI Example"
echo "================================================================================"
echo

# Step 1: Build LXR Package
# -------------------------
echo "Step 1: Building LXR package from configuration"
echo "--------------------------------------------------------------------------------"
echo "Config: $CONFIG_PATH"
echo "Output: $OUTPUT_PATH"
echo

bundle exec exe/lutaml-xsd build from-config "$CONFIG_PATH" \
  --output "$OUTPUT_PATH" \
  --xsd-mode include_all \
  --resolution-mode resolved \
  --serialization-format marshal \
  --name "Simple Example Schemas" \
  --version "1.0.0" \
  --description "Basic person and company schemas for demonstration"

echo
echo "✓ Package created successfully"
echo

# Step 2: Inspect Package
# -----------------------
echo "Step 2: Inspecting package contents"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg stats "$OUTPUT_PATH"

echo

# Step 3: Search for Types
# -------------------------
echo "Step 3: Searching for types"
echo "--------------------------------------------------------------------------------"
echo

echo "Searching for 'Person':"
bundle exec exe/lutaml-xsd pkg search Person "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Company':"
bundle exec exe/lutaml-xsd pkg search Company "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Address':"
bundle exec exe/lutaml-xsd pkg search Address "$OUTPUT_PATH" --limit 5

echo

# Step 4: Resolve Type References
# --------------------------------
echo "Step 4: Resolving type references"
echo "--------------------------------------------------------------------------------"
echo

echo "Resolving 'p:PersonType':"
bundle exec exe/lutaml-xsd pkg type find p:PersonType "$OUTPUT_PATH"

echo
echo "Resolving 'c:CompanyType':"
bundle exec exe/lutaml-xsd pkg type find c:CompanyType "$OUTPUT_PATH"

echo
echo "Resolving 'p:EmailType':"
bundle exec exe/lutaml-xsd pkg type find p:EmailType "$OUTPUT_PATH"

echo

# Step 5: List Namespaces
# ------------------------
echo "Step 5: Listing namespaces"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg namespace list "$OUTPUT_PATH"

echo

# Summary
echo "================================================================================"
echo "Example completed successfully!"
echo
echo "Key concepts demonstrated:"
echo "  ✓ Building LXR packages from YAML configuration"
echo "  ✓ Package statistics and inspection"
echo "  ✓ Type searching with CLI"
echo "  ✓ Type resolution by qualified name"
echo "  ✓ Namespace listing"
echo
echo "Output files:"
echo "  - $OUTPUT_PATH"
echo "================================================================================"