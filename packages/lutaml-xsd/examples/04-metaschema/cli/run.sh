#!/bin/bash
# Metaschema Example - CLI
#
# This script demonstrates:
# - Building LXR packages from self-referential schemas
# - Handling XSD schemas defining XSD structure
# - Working with meta-level definitions
#
# Usage:
#   bash examples/04-metaschema/cli/run.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$EXAMPLE_DIR/config.yml"
OUTPUT_PATH="$EXAMPLE_DIR/metaschema.lxr"

echo "================================================================================"
echo "04-METASCHEMA: CLI Example"
echo "================================================================================"
echo

# Step 1: Build LXR Package
# -------------------------
echo "Step 1: Building LXR package from NIST Metaschema definition"
echo "--------------------------------------------------------------------------------"
echo "Config: $CONFIG_PATH"
echo "Output: $OUTPUT_PATH"
echo "(Processing self-referential schema...)"
echo

bundle exec exe/lutaml-xsd build from-config "$CONFIG_PATH" \
  --output "$OUTPUT_PATH" \
  --xsd-mode include_all \
  --resolution-mode resolved \
  --serialization-format marshal \
  --name "NIST Metaschema Definition" \
  --version "1.0" \
  --description "XSD schema defining the Metaschema model structure"

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

# Step 3: Search for Metaschema Definition Types
# -----------------------------------------------
echo "Step 3: Searching for metaschema definition types"
echo "--------------------------------------------------------------------------------"
echo

echo "Searching for 'Definition':"
bundle exec exe/lutaml-xsd pkg search Definition "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Assembly':"
bundle exec exe/lutaml-xsd pkg search Assembly "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Constraint':"
bundle exec exe/lutaml-xsd pkg search Constraint "$OUTPUT_PATH" --limit 5

echo

# Step 4: List Types by Category
# -------------------------------
echo "Step 4: Viewing schema summary"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg ls "$OUTPUT_PATH"

echo

# Step 5: Resolve Meta-Level Types
# ---------------------------------
echo "Step 5: Searching for metaschema types"
echo "--------------------------------------------------------------------------------"
echo

echo "Attempting to resolve metaschema types..."
echo "(Note: Exact type names may vary)"
bundle exec exe/lutaml-xsd pkg search "Type" "$OUTPUT_PATH" --limit 3

echo

# Step 6: List Namespaces
# ------------------------
echo "Step 6: Listing namespaces"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg namespace list "$OUTPUT_PATH"

echo

# Step 7: View Package Tree
# --------------------------
echo "Step 7: Viewing package structure (first 20 lines)"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg tree "$OUTPUT_PATH" | head -20
echo "... (truncated)"

echo

# Summary
echo "================================================================================"
echo "Example completed successfully!"
echo
echo "Key concepts demonstrated:"
echo "  ✓ Building packages from self-referential schemas"
echo "  ✓ Handling XSD schemas defining XSD structure"
echo "  ✓ Meta-level type definitions"
echo "  ✓ Package structure inspection"
echo
echo "NIST Metaschema:"
echo "  - Defines modeling language for data structures"
echo "  - Self-referential (defines its own structure)"
echo "  - Used by OSCAL and other NIST standards"
echo
echo "Output files:"
echo "  - $OUTPUT_PATH"
echo "================================================================================"