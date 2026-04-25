#!/usr/bin/env bash
input=$(cat)

caveman_text=""
caveman_flag="$HOME/.claude/.caveman-active"
if [ -f "$caveman_flag" ]; then
  caveman_mode=$(cat "$caveman_flag" 2>/dev/null)
  if [ "$caveman_mode" = "full" ] || [ -z "$caveman_mode" ]; then
    caveman_text=$'\033[38;5;172m[CAVEMAN]\033[0m'
  else
    caveman_suffix=$(echo "$caveman_mode" | tr '[:lower:]' '[:upper:]')
    caveman_text=$'\033[38;5;172m[CAVEMAN:'"${caveman_suffix}"$']\033[0m'
  fi
fi

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

WORKTREE=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
WORKTREE_TEXT=""
[ -n "$WORKTREE" ] && WORKTREE_TEXT=" | 🪵 ${WORKTREE##*/}"

RL_5H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RL_7D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
RL_TEXT=""
if [ -n "$RL_5H_PCT" ] || [ -n "$RL_7D_PCT" ]; then
  RL_5H_PCT="${RL_5H_PCT:--}"; RL_7D_PCT="${RL_7D_PCT:--}"
  if [ "$RL_5H_PCT" != "-" ] && [ "$RL_5H_PCT" -ge 80 ] 2>/dev/null; then
    RL_TEXT=" | ${RED}⚡${RL_5H_PCT}%/5h ${RL_7D_PCT}%/7d${RESET}"
  else
    RL_TEXT=" | ${YELLOW}⚡${RL_5H_PCT}%/5h ${RL_7D_PCT}%/7d${RESET}"
  fi
fi

echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH$WORKTREE_TEXT"
COST_FMT=$(printf '$%.2f' "$COST")
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s$RL_TEXT | $caveman_text"