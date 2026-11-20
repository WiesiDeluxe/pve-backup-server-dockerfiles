#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]] && [[ $# -ne 2 ]]; then
  echo "usage: $0 <repos-file> [repo_name]"
  exit 1
fi

PROXMOX_GIT_URL="${PROXMOX_GIT_URL:-git://git.proxmox.com/git}"
SUBMODULE_URLS="$(dirname "$1")/submodule-urls"

perform() {
  if [[ ! -d "$1" ]]; then
    git clone "${PROXMOX_GIT_URL}/${3:-$1}.git" "$1"
  else
    git -C "$1" fetch
  fi
  git -C "$1" checkout "$2" -f
  git -C "$1" clean -ffdx
  # Optional submodule URL overrides (repos/submodule-urls: "<repo> <submodule-name> <url>"),
  # for submodule commits not yet present in the git.proxmox.com mirror. The commit
  # itself is still pinned by the parent repository, so only the fetch source changes.
  if [[ -f "$SUBMODULE_URLS" ]]; then
    while read -r S_REPO S_NAME S_URL S_REST; do
      [[ "$S_REPO" == "$1" ]] || continue
      git -C "$1" submodule init
      git -C "$1" config "submodule.${S_NAME}.url" "$S_URL"
      echo "$1: submodule $S_NAME from $S_URL" 1>&2
    done < <(grep -v '^#' "$SUBMODULE_URLS")
  fi
  git -C "$1" submodule update --init --recursive
  git -C "$1" submodule foreach git reset --hard
  git -C "$1" submodule foreach git clean -ffdx

  # set the same timestamps for all files, required by some Makefiles
  ( cd "$1"; git ls-files -z | xargs -0 touch -h )
}

while read REPO COMMIT_SHA REST; do
  [[ -n "$REPO" ]] || continue
  [[ -n "$2" ]] && [[ "$REPO" != "$2" ]] && continue

  echo "$REPO $COMMIT_SHA..." 1>&2
  REPO_URL=${REST%%#*}
  ( perform "$REPO" "$COMMIT_SHA" $REPO_URL )
done < "$1"
