#!/bin/bash
# UnitsML Example - CLI
#
# This script demonstrates:
# - Building LXR packages from scientific standards
# - Working with specialized vocabulary
# - Type discovery via CLI
#
# Usage:
#   bash examples/03-unitsml/cli/run.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$EXAMPLE_DIR/config.yml"
OUTPUT_PATH="$EXAMPLE_DIR/unitsml.lxr"

echo "================================================================================"
echo "03-UNITSML: CLI Example"
echo "================================================================================"
echo

# Step 1: Build LXR Package
# -------------------------
echo "Step 1: Building LXR package from UnitsML schema"
echo "--------------------------------------------------------------------------------"
echo "Config: $CONFIG_PATH"
echo "Output: $OUTPUT_PATH"
echo

bundle exec exe/lutaml-xsd build from-config "$CONFIG_PATH" \
  --output "$OUTPUT_PATH" \
  --xsd-mode include_all \
  --resolution-mode resolved \
  --serialization-format marshal \
  --name "UnitsML Schemas" \
  --version "1.0-csd04" \
  --description "OASIS UnitsML standard for units of measure"

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

# Step 3: Search for Unit-Related Types
# --------------------------------------
echo "Step 3: Searching for unit-related types"
echo "--------------------------------------------------------------------------------"
echo

echo "Searching for 'Unit':"
bundle exec exe/lutaml-xsd pkg search Unit "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Quantity':"
bundle exec exe/lutaml-xsd pkg search Quantity "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Dimension':"
bundle exec exe/lutaml-xsd pkg search Dimension "$OUTPUT_PATH" --limit 5

echo

# Step 4: List All Types
# -----------------------
echo "Step 4: Listing types (first 10)"
echo "--------------------------------------------------------------------------------"
echo

echo "(Using pkg ls to show schema summary)"
bundle exec exe/lutaml-xsd pkg ls "$OUTPUT_PATH"

echo

# Step 5: List Namespaces
# ------------------------
echo "Step 5: Listing namespaces"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg namespace list "$OUTPUT_PATH"

echo

# Step 6: View Package Metadata
# ------------------------------
echo "Step 6: Viewing package metadata"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg metadata get "$OUTPUT_PATH" --all

echo

# Summary
echo "================================================================================"
echo "Example completed successfully!"
echo
echo "Key concepts demonstrated:"
echo "  ✓ Building packages from scientific standards"
echo "  ✓ Working with specialized vocabulary"
echo "  ✓ Type discovery and categorization"
echo "  ✓ Package metadata inspection"
echo
echo "UnitsML Standard:"
echo "  - Defines units of measure"
echo "  - Supports scientific calculations"
echo "  - Standardized vocabulary"
echo
echo "Output files:"
echo "  - $OUTPUT_PATH"
echo "================================================================================"