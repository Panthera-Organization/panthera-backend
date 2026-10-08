#!/usr/bin/env bash
# Read changed paths on stdin, one per line.
# Exit 0 when the local database checks and the staging deploy should run.
found=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    supabase/*|\
    .github/actions/backend-checks/*|\
    .github/stack-changes.sh|\
    .github/workflows/ci.yml|\
    .github/workflows/deploy.yml)
      found=1
      ;;
  esac
done

if [ "$found" -eq 1 ]; then
  echo "Database and function checks apply."
  exit 0
fi

echo "No database, function, or workflow changes."
exit 1
