# Dependency Update Skill

This skill automates the process of checking for outdated dependencies and creating update PRs with verification.

## Overview

The dependency update skill will:
1. Scan `pyproject.toml` and `requirements*.txt` files for outdated packages
2. Check compatibility between proposed updates
3. Run the test suite against updated dependencies
4. Generate a summary report of changes and any breaking changes detected

## Usage

This skill is triggered automatically or can be invoked manually to keep project dependencies current.

### Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `target_files` | string[] | No | Specific dependency files to check (defaults to all) |
| `update_strategy` | string | No | `patch`, `minor`, or `major` (defaults to `minor`) |
| `dry_run` | boolean | No | If true, report changes without applying them (defaults to `false`) |
| `skip_packages` | string[] | No | List of package names to exclude from updates |

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `updated_packages` | object[] | List of packages that were updated with old/new versions |
| `skipped_packages` | object[] | Packages skipped due to compatibility issues or exclusion rules |
| `test_result` | string | `passed`, `failed`, or `skipped` |
| `report_path` | string | Path to the generated update report |

## Configuration

The skill reads configuration from `.agents/skills/dependency-update/config.yaml` if present.

### Example Config

```yaml
update_strategy: minor
skip_packages:
  - openai  # managed separately
test_command: "make test"
report_output: ".agents/reports/dependency-updates.md"
```

## How It Works

1. **Discovery**: The script locates all dependency manifests in the repo root
2. **Version Check**: Uses `pip index versions` and PyPI API to find latest compatible versions
3. **Compatibility Check**: Resolves the full dependency graph to detect conflicts before applying changes
4. **Apply Updates**: Modifies the dependency files in-place
5. **Verification**: Runs `pip install -e .[dev]` and the project test suite
6. **Reporting**: Writes a markdown summary to the configured output path

## Notes

- This skill requires Python 3.9+ and `pip` 22+
- The skill will not downgrade packages
- If tests fail after an update, the changes are reverted automatically and the package is added to the skipped list
- Major version updates are always flagged for human review regardless of test results
