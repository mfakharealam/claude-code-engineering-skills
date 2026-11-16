#!/usr/bin/env bash
# Raw signal for one day, in four labelled sections. Usage: collect.sh [YYYY-MM-DD]
DAY="${1:-$(date +%F)}"
REPOS_DIR="${REPOS_DIR:-$HOME/code}"
GH_LOGIN="${GH_LOGIN:-$(gh api user --jq .login 2>/dev/null)}"
CLAUDE_DIRS="${CLAUDE_DIRS:-$HOME/.claude/projects}"

echo "===== DAY: $DAY ====="

echo
echo "===== GIT ====="
for g in $(find "$REPOS_DIR" -maxdepth 3 -name .git 2>/dev/null); do
  repo="$(dirname "$g")"
  out=$(git -C "$repo" log --all --no-merges \
        --since="$DAY 00:00" --until="$DAY 23:59:59" \
        --author="$(git -C "$repo" config user.email)" \
        --pretty='  %h%d %s' 2>/dev/null)
  [ -n "$out" ] && printf '%s\n%s\n' "[$(basename "$repo")]" "$out"
done

echo
echo "===== GITHUB ACTIVITY ====="
gh api "/users/$GH_LOGIN/events?per_page=100" 2>/dev/null \
  | jq -r --arg day "$DAY" '
      .[] | select(.created_at[0:10]==$day)
      | "  \(.repo.name) \(.type|sub("Event";""))"
        + (if .payload.number then " #\(.payload.number)" elif .payload.issue then " #\(.payload.issue.number)" else "" end)
        + (if .payload.action then " \(.payload.action)" else "" end)
        + (if .payload.ref then " \(.payload.ref)" else "" end)' | sort | uniq -c

echo
echo "===== PRs / ISSUES TOUCHED ====="
gh search prs --involves=@me --updated="$DAY" --limit 40 \
  --json number,title,repository,state 2>/dev/null \
  | jq -r '.[] | "  \(.repository.nameWithOwner) PR #\(.number) [\(.state)] \(.title)"'
gh search issues --involves=@me --updated="$DAY" --limit 40 \
  --json number,title,repository,state 2>/dev/null \
  | jq -r '.[] | "  \(.repository.nameWithOwner) issue #\(.number) [\(.state)] \(.title)"'

echo
echo "===== SESSION PROMPTS ====="
for f in $(find $CLAUDE_DIRS -name '*.jsonl' -newermt "$DAY 00:00" 2>/dev/null); do
  jq -r --arg day "$DAY" '
    select(.type=="user" and (.isSidechain|not) and .userType=="external")
    | select((.timestamp // "")[0:10] == $day)
    | . as $m
    | (if ($m.message.content|type)=="string" then $m.message.content
       else ([$m.message.content[]? | select(.type=="text") | .text] | join(" ")) end) as $t
    | select($t != "")
    | select($t | test("^(<command-|<local-command|<task-notification|<user-prompt-submit|Another Claude session|\\[Request interrupted|Review this change for security vulnerabilities|Caveat:)") | not)
    | select($t | test("tool_result") | not)
    | "  \($m.timestamp[11:16]) | \($m.cwd | sub("/\\.claude/worktrees/.*$";"")) | \($t | gsub("\\s+";" ") | .[0:260])"
  ' "$f" 2>/dev/null
done | sort -u
