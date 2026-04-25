#!/usr/bin/env bash
# Tests for hooks/pre-compact.sh — stack detection and output format
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

HOOK="${REPO_ROOT}/hooks/pre-compact.sh"

setup_tmp

# Helper: run hook from a project dir, return stdout
run_hook() {
  local dir="$1"
  bash "$HOOK" 2>/dev/null
}

# ── Output format ─────────────────────────────────────────────────────────────

suite "output format — always present"

out=$(cd "$TMPDIR_TEST" && bash "$HOOK" 2>/dev/null)
assert_contains "contains section header"     "## Compact Instructions" "$out"
assert_contains "contains MUST PRESERVE"      "MUST PRESERVE"          "$out"
assert_contains "contains DO NOT PRESERVE"    "DO NOT PRESERVE"        "$out"
assert_contains "contains COMPRESSION RULE"   "COMPRESSION RULE"       "$out"
assert_contains "contains Active Task"        "Active Task"            "$out"
assert_contains "contains Errors"             "Errors"                 "$out"
assert_contains "contains Key Files"          "Key Files"              "$out"

# ── Stack detection — JavaScript / TypeScript ─────────────────────────────────

suite "stack detection — JavaScript"

js_dir="${TMPDIR_TEST}/proj_js"
mkdir -p "$js_dir"
echo '{"name":"app","dependencies":{}}' > "${js_dir}/package.json"

out=$(cd "$js_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "JS: Stack line present"    "Stack:" "$out"
assert_contains "JS: project type includes js" "javascript" "$out"

suite "stack detection — TypeScript"

ts_dir="${TMPDIR_TEST}/proj_ts"
mkdir -p "$ts_dir"
echo '{"name":"app"}' > "${ts_dir}/package.json"
echo '{}' > "${ts_dir}/tsconfig.json"

out=$(cd "$ts_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "TS: project type includes typescript" "typescript" "$out"

suite "stack detection — Next.js"

next_dir="${TMPDIR_TEST}/proj_next"
mkdir -p "$next_dir"
echo '{"name":"app","dependencies":{"next":"14.0.0"},"devDependencies":{}}' > "${next_dir}/package.json"
echo '{}' > "${next_dir}/tsconfig.json"

out=$(cd "$next_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "Next.js: project type includes nextjs" "nextjs" "$out"

suite "stack detection — Go"

go_dir="${TMPDIR_TEST}/proj_go"
mkdir -p "$go_dir"
printf 'module github.com/example/myapp\n\ngo 1.21\n' > "${go_dir}/go.mod"

out=$(cd "$go_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "Go: stack present"           "Stack:" "$out"
assert_contains "Go: project type is go"      "go"     "$out"
assert_contains "Go: module name included"    "github.com/example/myapp" "$out"
assert_contains "Go: test command"            "go test ./..." "$out"
assert_contains "Go: build command"           "go build ./..." "$out"

suite "stack detection — Python"

py_dir="${TMPDIR_TEST}/proj_py"
mkdir -p "$py_dir"
touch "${py_dir}/requirements.txt"

out=$(cd "$py_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "Python: project type" "python" "$out"
assert_contains "Python: test command" "pytest" "$out"

suite "stack detection — Rust"

rs_dir="${TMPDIR_TEST}/proj_rs"
mkdir -p "$rs_dir"
printf '[package]\nname = "myapp"\nversion = "0.1.0"\n' > "${rs_dir}/Cargo.toml"

out=$(cd "$rs_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "Rust: project type"    "rust"         "$out"
assert_contains "Rust: test command"    "cargo test"   "$out"
assert_contains "Rust: build command"   "cargo build"  "$out"

suite "stack detection — no project files"

empty_dir="${TMPDIR_TEST}/proj_empty"
mkdir -p "$empty_dir"

out=$(cd "$empty_dir" && bash "$HOOK" 2>/dev/null)
assert_not_contains "no Stack line for empty dir" "Stack:" "$out"

# ── Schema detection ──────────────────────────────────────────────────────────

suite "schema detection"

schema_dir="${TMPDIR_TEST}/proj_schema"
mkdir -p "${schema_dir}/prisma"
touch "${schema_dir}/prisma/schema.prisma"
echo '{"name":"app"}' > "${schema_dir}/package.json"

out=$(cd "$schema_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "schema file detected" "prisma/schema.prisma" "$out"
assert_contains "schema preservation note" "Schema" "$out"

# ── API directory detection ───────────────────────────────────────────────────

suite "API directory detection"

api_dir="${TMPDIR_TEST}/proj_api"
mkdir -p "${api_dir}/src/api"
echo '{"name":"app"}' > "${api_dir}/package.json"

out=$(cd "$api_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "API dir detected" "src/api" "$out"

# ── Git state ─────────────────────────────────────────────────────────────────

suite "git state"

git_dir="${TMPDIR_TEST}/proj_git"
mkdir -p "$git_dir"
git -C "$git_dir" init -q
git -C "$git_dir" checkout -q -b my-feature 2>/dev/null || true

out=$(cd "$git_dir" && bash "$HOOK" 2>/dev/null)
assert_contains "git branch included" "my-feature" "$out"

suite "no git repo"

nogit_dir="${TMPDIR_TEST}/proj_nogit"
mkdir -p "$nogit_dir"

out=$(cd "$nogit_dir" && bash "$HOOK" 2>/dev/null)
assert_not_contains "no Branch line without git" "Branch:" "$out"

# ── Exit code ────────────────────────────────────────────────────────────────

suite "exit code"

(cd "$TMPDIR_TEST" && bash "$HOOK" >/dev/null 2>/dev/null)
assert_exit_ok "exits 0" "$?"

summary
