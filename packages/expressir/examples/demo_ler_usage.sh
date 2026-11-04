#!/bin/bash
# Complete LER Demonstration Script
# Shows package creation, searching, and querying using CLI commands

set -e

echo "======================================================================"
echo "           LER Package Creation and Query Demonstration              "
echo "======================================================================"
echo

# Step 1: Create LER package
echo "Step 1: Creating LER Package"
echo "----------------------------------------------------------------------"
echo "Building from: examples/ler/simple_schema.exp"
echo

bundle exec expressir package build \
  examples/ler/simple_schema.exp \
  examples/ler/simple_example.ler \
  --name "Simple Product Management Schema" \
  --version "1.0.0" \
  --description "Demonstrates LER features with product entities" \
  --express-mode include_all \
  --resolution-mode resolved \
  --serialization-format yaml

echo "✓ Package created: examples/ler/simple_example.ler"
echo

# Step 2: Show package info
echo "Step 2: Package Information"
echo "----------------------------------------------------------------------"
bundle exec expressir package info examples/ler/simple_example.ler
echo

# Step 3: List entities
echo "Step 3: List All Entities"
echo "----------------------------------------------------------------------"
bundle exec expressir package list examples/ler/simple_example.ler --type entity
echo

# Step 4: List types
echo "Step 4: List All Types"
echo "----------------------------------------------------------------------"
bundle exec expressir package list examples/ler/simple_example.ler --type type
echo

# Step 5: Search with patterns
echo "Step 5: Search with Wildcard Pattern 'product*'"
echo "----------------------------------------------------------------------"
bundle exec expressir package search examples/ler/simple_example.ler "product*"
echo

# Step 6: Search specific type
echo "Step 6: Search for Entities Only"
echo "----------------------------------------------------------------------"
bundle exec expressir package search examples/ler/simple_example.ler "product" --type entity
echo

# Step 7: Validation
echo "Step 7: Package Validation"
echo "----------------------------------------------------------------------"
bundle exec expressir package validate examples/ler/simple_example.ler \
  --strict \
  --check-interfaces \
  --check-completeness
echo

# Step 8: Tree view
echo "Step 8: Package Tree View"
echo "----------------------------------------------------------------------"
bundle exec expressir package tree examples/ler/simple_example.ler --depth 3
echo

echo "======================================================================"
echo "  Demo Complete!"
echo "======================================================================"
echo
echo "Package saved at: examples/ler/simple_example.ler"
echo
echo "Try these additional commands:"
echo "  expressir package info examples/ler/simple_example.ler --format json"
echo "  expressir package search examples/ler/simple_example.ler 'product_*' --regex"
echo "  expressir package tree examples/ler/simple_example.ler --counts"
echo