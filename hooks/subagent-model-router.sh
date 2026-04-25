#!/usr/bin/env bash
# PreToolUse hook — intercepts Agent tool calls and routes to optimal model.
#
# Tiers:
#   haiku  — pure lookup/exploration (Explore, statusline-setup, claude-code-guide)
#   sonnet — analysis/implementation (Plan, superpowers:code-reviewer,
#             general-purpose with complex/long prompt)
#   (exit 0, no override) — everything else inherits parent model
#
# Uses updatedInput (exit 0 + JSON stdout) so the tool still runs — not a block.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ "$tool_name" != "Agent" ] && exit 0

subagent_type=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null) || exit 0

emit_model() {
  local model="$1"
  local updated_input
  updated_input=$(printf '%s' "$input" | jq --arg m "$model" '.tool_input + {"model": $m}' 2>/dev/null) || exit 0
  jq -n --argjson ui "$updated_input" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: $ui
    }
  }'
  exit 0
}

# Route by subagent type
case "$subagent_type" in
  Plan|superpowers:code-reviewer)
    emit_model "sonnet"
    ;;
  Explore|statusline-setup|claude-code-guide)
    emit_model "haiku"
    ;;
esac

# general-purpose (explicit or empty → default) — route by prompt complexity
if [ "$subagent_type" = "general-purpose" ] || [ -z "$subagent_type" ]; then
  prompt=$(printf '%s' "$input" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]') || exit 0

  # Long prompts signal complexity regardless of keywords
  word_count=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
  if [ "$word_count" -gt 80 ]; then
    emit_model "sonnet"
  fi

  # Complexity keywords → Sonnet
  if printf '%s' "$prompt" | grep -qE \
    'implement|build|create|generate|write|design|architect|fix|debug|refactor|migrate|integrate|parse|why|compare|analyze|analyse|explain how|how does|evaluate|optimize|suggest|recommend|plan|strategy|tradeoff|trade-off|test'; then
    emit_model "sonnet"
  fi

  # Simple lookup/exploration → Haiku
  emit_model "haiku"
fi

# All other subagent types: inherit parent model
exit 0
