#!/usr/bin/env bash
# Run this from the root of the repository.

git filter-branch --env-filter '
# ---------- hard-coded old identity -----------------------------------
OLD_EMAIL="tiago@MacBook-Pro-de-Tiago.local"
# ---------- hard-coded new identity -----------------------------------
NEW_NAME="Tiago Daniel Jacobs"
NEW_EMAIL="tiago.jacobs@gmail.com"
# ----------------------------------------------------------------------

# If the author is wrong, rewrite it
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]; then
    export GIT_AUTHOR_NAME="$NEW_NAME"
    export GIT_AUTHOR_EMAIL="$NEW_EMAIL"
fi

# If the committer is wrong, rewrite it
if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]; then
    export GIT_COMMITTER_NAME="$NEW_NAME"
    export GIT_COMMITTER_EMAIL="$NEW_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags

echo ""
echo "✔️  All done.  If this repo is on a remote you own, force-push now:"
echo "   git push --force --tags"

