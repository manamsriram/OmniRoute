#!/usr/bin/env bash
# Finds the newest upstream `release/*` branch, sorted as versions (not lexically).
#
# Usage: find_latest_release_branch.sh <upstream-git-url>
# Prints two lines to stdout:
#   branch=release/vX.Y.Z
#   version=vX.Y.Z
set -euo pipefail

UPSTREAM_URL="${1:?usage: find_latest_release_branch.sh <upstream-git-url>}"

# List remote heads matching refs/heads/release/*, strip ref path down to the branch name.
mapfile -t branches < <(
  git ls-remote --heads "$UPSTREAM_URL" 'refs/heads/release/*' \
    | awk '{print $2}' \
    | sed 's#^refs/heads/##'
)

if [[ ${#branches[@]} -eq 0 ]]; then
  echo "::error::No release/* branches found on $UPSTREAM_URL" >&2
  exit 1
fi

# Sort by the version suffix (release/vX.Y.Z -> X.Y.Z) using `sort -V` (true version sort,
# not lexicographic — so v3.8.9 sorts before v3.8.10).
latest_branch=$(
  printf '%s\n' "${branches[@]}" \
    | sed -E 's#^release/v##' \
    | sort -V \
    | tail -n1 \
    | sed -E 's#^#release/v#'
)

version="${latest_branch#release/}"

echo "branch=${latest_branch}"
echo "version=${version}"
