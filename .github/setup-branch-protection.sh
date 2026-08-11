#!/usr/bin/env bash
#
# Enforce Rule 1: the default branch is updated through pull requests only,
# and a PR may be merged only when the CI workflow ("Build and test") is green.
#
# GitHub branch protection lives in repository settings, not in a workflow
# file, so it must be applied via the API. Run this once (re-running is safe).
#
# Requirements:
#   - gh CLI, authenticated with admin rights on the repository
#     (gh auth login)
#
# Usage:
#   .github/setup-branch-protection.sh [owner/repo] [branch]
#   # defaults: current repo, branch "master"

set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-master}"

echo "Applying branch protection to ${REPO}@${BRANCH} ..."

gh api -X PUT "repos/${REPO}/branches/${BRANCH}/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Build and test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

echo "Done."
echo
echo "Effect:"
echo "  - Direct pushes to ${BRANCH} are rejected (PR required), admins included."
echo "  - A PR merges only after the 'Build and test' check passes."
echo "  - 'strict' requires the branch to be up to date with ${BRANCH} before merge."
