#!/usr/bin/env bash
# Usage: codex-items.sh <PR> [owner/repo]
# Prints the PR's pending review items as one JSON object per line:
#   {kind, id, path, line, created_at, outdated, body}
# kind: inline — the root of a review thread that is not resolved and has no reply yet.
#       summary — a review submitted with a body (codex's summary sometimes carries findings).
# Nothing is matched by title or author: codex posts under the user's own login and its
# wording changes, so whatever is open and unanswered on the PR is what needs triage.
set -euo pipefail
PR="$1"; REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OWNER="${REPO%/*}"; NAME="${REPO#*/}"

gh api graphql --paginate -F owner="$OWNER" -F name="$NAME" -F pr="$PR" -f query='
  query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            isOutdated
            comments(first: 2) {
              totalCount
              nodes { databaseId path line originalLine createdAt body }
            }
          }
        }
      }
    }
  }' | jq -c '
  .data.repository.pullRequest.reviewThreads.nodes[]
  | select(.isResolved | not)
  | select(.comments.totalCount == 1)
  | .comments.nodes[0] as $c
  | {kind:"inline", id:$c.databaseId, path:$c.path, line:($c.line // $c.originalLine),
     created_at:$c.createdAt, outdated:.isOutdated, body:$c.body}'

gh api "repos/$REPO/pulls/$PR/reviews" --paginate | jq -s -c '
  add // [] | map(select((.body // "") != ""))
  | .[] | {kind:"summary", id, path:null, line:null, created_at:.submitted_at, outdated:null, body}'
