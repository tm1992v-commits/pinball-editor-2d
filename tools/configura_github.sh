#!/bin/bash
# Configures the OFFICIAL repository on GitHub (run once by the lead maintainer, after the first push):
# protection of the main branch (pull request + approving review + passing tests required, no force push).
# Needs the GitHub CLI logged in: gh auth login. Usage: tools/configura_github.sh OWNER/REPO
set -e
REPO="${1:?Usage: tools/configura_github.sh OWNER/REPO}"
gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": {"strict": true, "contexts": ["test"]},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 1, "require_code_owner_reviews": true},
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "Branch protection set on $REPO (main): pull request, 1 approving review, tests required."
