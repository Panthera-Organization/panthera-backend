#!/usr/bin/env bash
# Copy the backend schema onto panthera-app and squash-merge that pull request.
# PB-104 stops this merge before the public release. The pull request then stays open.
set -euo pipefail

: "${APP_DIR:?}"
: "${APP_REPO:?}"
: "${BACKEND_SCHEMA:?}"
: "${BACKEND_SHA:?}"
: "${GH_TOKEN:?}"

APP_SCHEMA_PATH="schema.graphql"
BRANCH="bot/schema-snapshot"
TITLE="chore: Keep the app schema aligned with the backend"

if [ ! -f "$BACKEND_SCHEMA" ]; then
  echo "Backend schema is missing: ${BACKEND_SCHEMA}" >&2
  exit 1
fi

cd "$APP_DIR"

git fetch origin main
git fetch origin "$BRANCH" || true

open_pr_number() {
  gh pr list \
    --repo "$APP_REPO" \
    --head "$BRANCH" \
    --state open \
    --json number \
    --jq '.[0].number // empty'
}

pr_body() {
  cat <<EOF
Updates \`schema.graphql\` from panthera-backend \`${BACKEND_SHA}\`.

https://github.com/Panthera-Organization/panthera-backend/commit/${BACKEND_SHA}
EOF
}

base_copy=$(mktemp)
if git cat-file -e "origin/main:${APP_SCHEMA_PATH}" 2>/dev/null; then
  git show "origin/main:${APP_SCHEMA_PATH}" > "$base_copy"
else
  printf '' > "$base_copy"
fi

if cmp -s "$BACKEND_SCHEMA" "$base_copy"; then
  echo "schema.graphql on app main matches the backend."
  number=$(open_pr_number)
  if [ -n "$number" ]; then
    gh pr close "$number" \
      --repo "$APP_REPO" \
      --comment "schema.graphql on app main already matches panthera-backend ${BACKEND_SHA}."
  fi
  exit 0
fi

git checkout -B "$BRANCH" origin/main
cp "$BACKEND_SCHEMA" "$APP_SCHEMA_PATH"
git add -- "$APP_SCHEMA_PATH"

if git diff --cached --quiet; then
  echo "schema.graphql on app main matches the backend."
  exit 0
fi

login=$(gh api user --jq .login)
user_id=$(gh api user --jq .id)
git config user.name "$login"
git config user.email "${user_id}+${login}@users.noreply.github.com"

git commit -m "$(cat <<EOF
${TITLE}

Copy schema.graphql from panthera-backend at ${BACKEND_SHA}.
EOF
)"

if git rev-parse --verify --quiet "refs/remotes/origin/${BRANCH}" >/dev/null; then
  expected=$(git rev-parse "refs/remotes/origin/${BRANCH}")
  git push --force-with-lease="refs/heads/${BRANCH}:${expected}" origin "HEAD:refs/heads/${BRANCH}"
else
  git push origin "HEAD:refs/heads/${BRANCH}"
fi

number=$(open_pr_number)
if [ -z "$number" ]; then
  gh pr create \
    --repo "$APP_REPO" \
    --base main \
    --head "$BRANCH" \
    --title "$TITLE" \
    --body "$(pr_body)"
  number=$(open_pr_number)
fi

if [ -z "$number" ]; then
  echo "The schema branch was pushed, and no pull request was opened." >&2
  exit 1
fi

gh pr edit "$number" --repo "$APP_REPO" --title "$TITLE" --body "$(pr_body)"

url=$(gh pr view "$number" --repo "$APP_REPO" --json url --jq .url)
echo "Pull request: ${url}"

# GitHub may still be computing mergeability right after the push.
for _ in 1 2 3 4 5 6; do
  if gh pr merge "$number" --repo "$APP_REPO" --squash; then
    echo "Merged ${url}"
    exit 0
  fi
  sleep 5
done

echo "GitHub refused the merge. ${url} stays open." >&2
exit 1
