#!/usr/bin/env bash
# examples-auto-run skill script
# Discovers and runs all example scripts in the repo, capturing output and reporting results.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${ROOT_DIR}/examples"
REPORT_FILE="${ROOT_DIR}/.agents/skills/examples-auto-run/report.md"
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30}
PYTHON=${PYTHON:-python}

PASSED=0
FAILED=0
SKIPPED=0
FAILED_EXAMPLES=()

log() {
  echo "[examples-auto-run] $*"
}

check_dependencies() {
  if ! command -v "$PYTHON" &>/dev/null; then
    log "ERROR: Python interpreter '${PYTHON}' not found."
    exit 1
  fi
  if [ ! -d "$EXAMPLES_DIR" ]; then
    log "ERROR: Examples directory not found at ${EXAMPLES_DIR}"
    exit 1
  fi
}

should_skip() {
  local file="$1"
  # Skip files that contain a special marker indicating they require manual setup
  if grep -q '# SKIP_AUTO_RUN' "$file" 2>/dev/null; then
    return 0
  fi
  # Skip files that require interactive input
  if grep -qE 'input\(|getpass\.' "$file" 2>/dev/null; then
    return 0
  fi
  return 1
}

run_example() {
  local file="$1"
  local rel_path
  rel_path="$(realpath --relative-to="$ROOT_DIR" "$file")"

  if should_skip "$file"; then
    log "SKIP  ${rel_path}"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  log "RUN   ${rel_path}"
  local output
  local exit_code=0

  output=$(cd "$ROOT_DIR" && timeout "$TIMEOUT_SECONDS" "$PYTHON" "$file" 2>&1) || exit_code=$?

  if [ $exit_code -eq 124 ]; then
    log "TIMEOUT ${rel_path} (>${TIMEOUT_SECONDS}s)"
    FAILED=$((FAILED + 1))
    FAILED_EXAMPLES+=("${rel_path} (timeout)")
  elif [ $exit_code -ne 0 ]; then
    log "FAIL  ${rel_path} (exit code ${exit_code})"
    log "      Output: $(echo "$output" | tail -5)"
    FAILED=$((FAILED + 1))
    FAILED_EXAMPLES+=("${rel_path} (exit ${exit_code})")
  else
    log "PASS  ${rel_path}"
    PASSED=$((PASSED + 1))
  fi
}

generate_report() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  {
    echo "# Examples Auto-Run Report"
    echo ""
    echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Status  | Count |"
    echo "|---------|-------|"
    echo "| Passed  | ${PASSED} |"
    echo "| Failed  | ${FAILED} |"
    echo "| Skipped | ${SKIPPED} |"
    echo ""
    if [ ${#FAILED_EXAMPLES[@]} -gt 0 ]; then
      echo "## Failed Examples"
      echo ""
      for ex in "${FAILED_EXAMPLES[@]}"; do
        echo "- \`${ex}\`"
      done
      echo ""
    fi
  } > "$REPORT_FILE"
  log "Report written to ${REPORT_FILE}"
}

main() {
  log "Starting examples auto-run from ${EXAMPLES_DIR}"
  check_dependencies

  # Find all top-level example Python files and __main__ entrypoints
  while IFS= read -r -d '' file; do
    run_example "$file"
  done < <(find "$EXAMPLES_DIR" -name '*.py' -not -path '*/__pycache__/*' -print0 | sort -z)

  generate_report

  log "Done. Passed=${PASSED} Failed=${FAILED} Skipped=${SKIPPED}"

  if [ $FAILED -gt 0 ]; then
    log "Some examples failed. See ${REPORT_FILE} for details."
    exit 1
  fi
}

main "$@"
