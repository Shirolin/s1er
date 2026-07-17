#!/bin/sh
#
# S1 Client — Git pre-commit checks
# Installed as a thin wrapper via: scripts/install_precommit.ps1
#
# Modes (env S1_PRECOMMIT):
#   full  (default) — format + analyze + test + M3 audit
#   lite  / quick   — format + analyze only（小改小修）
#   skip  / off     — 不做检查直接放行（等价于 --no-verify）
#
# Examples:
#   git commit -m "..."
#   S1_PRECOMMIT=lite git commit -m "..."
#   # PowerShell:
#   $env:S1_PRECOMMIT='lite'; git commit -m "..."
#

set -e

MODE="${S1_PRECOMMIT:-full}"
case "$MODE" in
  lite|quick) MODE=lite ;;
  full|"") MODE=full ;;
  skip|off|0|false) MODE=skip ;;
  *)
    echo "Unknown S1_PRECOMMIT='$MODE' (expected: full | lite | skip)" >&2
    exit 1
    ;;
esac

if [ "$MODE" = skip ]; then
  echo "S1_PRECOMMIT=skip — pre-commit checks bypassed."
  exit 0
fi

if [ "$MODE" = lite ]; then
  TOTAL=2
  LABEL="lite (format + analyze)"
else
  TOTAL=4
  LABEL="full"
fi

echo "────────────────────────────────────────"
echo "  S1 Client — Pre-commit checks [$LABEL]"
echo "────────────────────────────────────────"
echo ""

# 1. Auto-format Dart sources
echo "[1/$TOTAL] dart format — auto-formatting..."
dart format lib test scripts
echo "  OK"
echo ""

# 2. Static analysis
echo "[2/$TOTAL] flutter analyze — static analysis..."
flutter analyze
echo "  OK"
echo ""

if [ "$MODE" = lite ]; then
  echo "────────────────────────────────────────"
  echo "  Lite checks passed! Commit allowed."
  echo "  (Set S1_PRECOMMIT=full or unset for tests + M3.)"
  echo "────────────────────────────────────────"
  exit 0
fi

# 3. Run tests
echo "[3/$TOTAL] flutter test — running tests..."
flutter test
echo "  OK"
echo ""

# 4. Material Design 3 audit
echo "[4/$TOTAL] dart run scripts/audit_m3.dart — M3 compliance..."
dart run scripts/audit_m3.dart --fail-on-error
echo "  OK"
echo ""

echo "────────────────────────────────────────"
echo "  All checks passed! Commit allowed."
echo "────────────────────────────────────────"
