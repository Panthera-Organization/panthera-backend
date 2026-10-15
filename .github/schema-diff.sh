#!/usr/bin/env bash
# Compare an old GraphQL schema to a new one.
# Exit 1 when the new schema contains a breaking change.
# Dangerous changes are printed. They do not fail the command.
# Removal of a field, enum value, or input field that is already @deprecated is dangerous.
# Removal of a type stays breaking.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: schema-diff.sh OLD_SCHEMA NEW_SCHEMA" >&2
  exit 2
fi

old=$1
new=$2

if [ ! -f "$old" ] || [ ! -f "$new" ]; then
  echo "Both schema files must exist." >&2
  exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
rule="${script_dir}/suppress-removal-of-deprecated-field.mjs"

exec npx --yes @graphql-inspector/cli@7.0.1 diff "$old" "$new" --rule "$rule"
