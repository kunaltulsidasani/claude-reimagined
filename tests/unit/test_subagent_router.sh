#!/usr/bin/env bash
# Tests for hooks/subagent-model-router.sh — routing decisions
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

HOOK="${REPO_ROOT}/hooks/subagent-model-router.sh"

# Helper: build Agent tool call JSON
agent_json() {
  local subagent_type="${1:-}"
  local prompt="${2:-find the file}"
  if [[ -z "$subagent_type" ]]; then
    jq -n --arg p "$prompt" '{tool_name:"Agent",tool_input:{prompt:$p}}'
  else
    jq -n --arg t "$subagent_type" --arg p "$prompt" \
      '{tool_name:"Agent",tool_input:{subagent_type:$t,prompt:$p}}'
  fi
}

# Helper: extract routed model from hook output JSON
routed_model() {
  printf '%s' "$1" | jq -r '.hookSpecificOutput.updatedInput.model // empty' 2>/dev/null
}

# ── Non-Agent tool calls ──────────────────────────────────────────────────────

suite "non-Agent tool calls"

out=$(jq -n '{tool_name:"Bash",tool_input:{command:"ls"}}' | bash "$HOOK" 2>/dev/null)
assert_eq "Bash tool → no output (pass-through)" "" "$out"

out=$(jq -n '{tool_name:"Read",tool_input:{file_path:"/tmp/x"}}' | bash "$HOOK" 2>/dev/null)
assert_eq "Read tool → no output" "" "$out"

# ── Explicit Sonnet types ─────────────────────────────────────────────────────

suite "Sonnet floor — explicit types"

out=$(agent_json "Plan" "design the system" | bash "$HOOK" 2>/dev/null)
assert_eq "Plan → sonnet" "sonnet" "$(routed_model "$out")"

out=$(agent_json "superpowers:code-reviewer" "review my PR" | bash "$HOOK" 2>/dev/null)
assert_eq "superpowers:code-reviewer → sonnet" "sonnet" "$(routed_model "$out")"

# ── Explicit Haiku types ──────────────────────────────────────────────────────

suite "Haiku — pure lookup types"

out=$(agent_json "Explore" "find all tsx files" | bash "$HOOK" 2>/dev/null)
assert_eq "Explore → haiku" "haiku" "$(routed_model "$out")"

out=$(agent_json "statusline-setup" "configure statusline" | bash "$HOOK" 2>/dev/null)
assert_eq "statusline-setup → haiku" "haiku" "$(routed_model "$out")"

out=$(agent_json "claude-code-guide" "how do hooks work" | bash "$HOOK" 2>/dev/null)
assert_eq "claude-code-guide → haiku" "haiku" "$(routed_model "$out")"

# ── general-purpose: prompt complexity routing ────────────────────────────────

suite "general-purpose — complexity keywords → Sonnet"

for kw in implement build create generate write design architect fix debug refactor migrate integrate parse analyze test; do
  out=$(agent_json "general-purpose" "$kw the thing" | bash "$HOOK" 2>/dev/null)
  assert_eq "keyword '$kw' → sonnet" "sonnet" "$(routed_model "$out")"
done

out=$(agent_json "general-purpose" "why does this fail" | bash "$HOOK" 2>/dev/null)
assert_eq "keyword 'why' → sonnet" "sonnet" "$(routed_model "$out")"

out=$(agent_json "general-purpose" "compare options A and B" | bash "$HOOK" 2>/dev/null)
assert_eq "keyword 'compare' → sonnet" "sonnet" "$(routed_model "$out")"

suite "general-purpose — simple prompt → Haiku"

out=$(agent_json "general-purpose" "find the config file" | bash "$HOOK" 2>/dev/null)
assert_eq "simple lookup → haiku" "haiku" "$(routed_model "$out")"

out=$(agent_json "general-purpose" "list all routes" | bash "$HOOK" 2>/dev/null)
assert_eq "list prompt → haiku" "haiku" "$(routed_model "$out")"

suite "general-purpose — long prompt (>80 words) → Sonnet"

long_prompt=$(printf 'word%.0s ' {1..85})  # 85 words
out=$(agent_json "general-purpose" "$long_prompt" | bash "$HOOK" 2>/dev/null)
assert_eq "85-word prompt → sonnet" "sonnet" "$(routed_model "$out")"

short_prompt="find the file in the repo"
out=$(agent_json "general-purpose" "$short_prompt" | bash "$HOOK" 2>/dev/null)
assert_eq "short prompt → haiku" "haiku" "$(routed_model "$out")"

# ── Empty subagent_type (defaults to general-purpose path) ───────────────────

suite "empty subagent_type — routes as general-purpose"

out=$(agent_json "" "find the config file" | bash "$HOOK" 2>/dev/null)
assert_eq "empty type + simple prompt → haiku" "haiku" "$(routed_model "$out")"

out=$(agent_json "" "implement the feature" | bash "$HOOK" 2>/dev/null)
assert_eq "empty type + complex keyword → sonnet" "sonnet" "$(routed_model "$out")"

# ── Unknown subagent type — inherit parent ────────────────────────────────────

suite "unknown subagent type — pass-through (no model override)"

out=$(agent_json "custom-agent" "do something" | bash "$HOOK" 2>/dev/null)
assert_eq "unknown type → no model in output" "" "$(routed_model "$out")"

# ── Output structure ──────────────────────────────────────────────────────────

suite "output JSON structure"

out=$(agent_json "Plan" "design" | bash "$HOOK" 2>/dev/null)
assert_contains "hookEventName present" "PreToolUse" "$out"
assert_contains "permissionDecision allow" "allow" "$out"
assert_contains "updatedInput present" "updatedInput" "$out"

summary
