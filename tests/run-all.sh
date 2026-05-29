#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"

declare -a tests=(
  "$TEST_DIR/test-uninstall.sh"
  "$TEST_DIR/test-conflicts.sh"
  "$TEST_DIR/test-requirements.sh"
  "$TEST_DIR/test-setup-dry-run.sh"
)

passed=0
failed=0

echo "=========================================="
echo "Running all tests..."
echo "=========================================="
printf '\n'

for test in "${tests[@]}"; do
  if [[ ! -f "$test" ]]; then
    echo "✗ SKIP: $test (no existe)"
    failed=$((failed + 1))
    continue
  fi

  if bash "$test"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  printf '\n'
done

echo "=========================================="
echo "Test results: $passed passed, $failed failed"
echo "=========================================="

if [[ "$failed" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
