#!/usr/bin/env bash
# ============================================================================
# Regenerates the auto-updated repo list inside README.md, between the markers
#   <!-- REPOS:START --> ... <!-- REPOS:END -->
#
# Public profile: lists PUBLIC, non-fork, non-archived repos owned by the user.
# Run locally (`./scripts/generate-readme.sh`) or from the GitHub Action.
# Requires: gh (authenticated) + jq.
# ============================================================================
set -euo pipefail

USER="${PROFILE_USER:-Zeev-L}"
README="${1:-README.md}"
START="<!-- REPOS:START -->"
END="<!-- REPOS:END -->"

# Fetch public, non-fork, non-archived repos, newest activity first.
ROWS=$(gh api --paginate "users/$USER/repos?per_page=100&type=owner&sort=pushed&direction=desc" \
  --jq '.[] | select(.fork==false and .private==false and .archived==false)
        | "| [\(.name)](\(.html_url)) | \(.description // "—") | \(.language // "—") | \(.updated_at[0:10]) | \(.stargazers_count) |"')

COUNT=$(printf '%s\n' "$ROWS" | grep -c '^|' || true)

# Write the table to a temp file (portable: avoids passing newlines via awk -v,
# which BSD/macOS awk rejects).
TABLE_FILE="$(mktemp)"
{
  printf '%s\n\n' "**$COUNT public repositories** · sorted by latest activity · updated automatically"
  printf '%s\n'   "| Repo | What it is | Lang | Updated | ⭐ |"
  printf '%s\n'   "|------|------------|------|---------|----|"
  printf '%s\n'   "$ROWS"
} > "$TABLE_FILE"

# Replace the content between the markers (markers themselves are preserved).
awk -v start="$START" -v end="$END" -v tablefile="$TABLE_FILE" '
  $0 ~ start {print; print ""; while ((getline line < tablefile) > 0) print line; close(tablefile); print ""; skip=1; next}
  $0 ~ end   {skip=0}
  !skip {print}
' "$README" > "$README.tmp" && mv "$README.tmp" "$README"
rm -f "$TABLE_FILE"

echo "Updated $README with $COUNT public repos."
