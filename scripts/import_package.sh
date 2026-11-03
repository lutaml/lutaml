#!/usr/bin/env bash
# Import another gem repository into packages/<name>/ keeping its history
# (monorepo step L4/L5, lutaml/lutaml#232, #233). Merges the source ref with
# --allow-unrelated-histories, then relocates the tree under packages/<name>.
# Run on a clean branch of a clean tree; it makes exactly one merge commit.
#
#   scripts/import_package.sh <name> <repo-url-or-path> <ref>
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <name> <repo-url-or-path> <ref>" >&2
  exit 64
fi
name=$1 source=$2 ref=$3
dest="packages/$name"

[ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 1; }
[ ! -e "$dest" ] || { echo "$dest already exists" >&2; exit 1; }

remote="import-$name"
git remote add "$remote" "$source"
trap 'git remote remove "$remote" 2>/dev/null || true' EXIT
git fetch --quiet --no-tags "$remote" "$ref"

git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD
git read-tree --prefix="$dest/" -u FETCH_HEAD
git commit -q -m "import $name into packages/$name"
echo "imported $name at $(git rev-parse --short FETCH_HEAD) into $dest"
