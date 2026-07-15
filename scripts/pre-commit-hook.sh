#!/bin/sh
#
# S1 Client — Git pre-commit hook
# Runs code quality checks before each commit.
# Install via: scripts/install_precommit.ps1
#

set -e

echo "────────────────────────────────────────"
echo "  S1 Client — Pre-commit checks"
echo "────────────────────────────────────────"
echo ""

# 1. Auto-format all Dart files
echo "[1/4] dart format — auto-formatting..."
dart format lib test scripts
echo "  OK"
echo ""

# 2. Static analysis
echo "[2/4] flutter analyze — static analysis..."
flutter analyze
echo "  OK"
echo ""

# 3. Run tests
echo "[3/4] flutter test — running tests..."
flutter test
echo "  OK"
echo ""

# 4. Material Design 3 audit
echo "[4/4] dart run scripts/audit_m3.dart — M3 compliance..."
dart run scripts/audit_m3.dart --fail-on-error
echo "  OK"
echo ""

echo "────────────────────────────────────────"
echo "  All checks passed! Commit allowed."
echo "────────────────────────────────────────"
