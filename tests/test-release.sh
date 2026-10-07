#!/bin/sh
# Test: the release files agree. Run it before each release tag.
. "$(dirname "$0")/lib.sh"

v=$(cat "$SRC/VERSION")
top=$(sed -n 's/^## v\([0-9][0-9.]*\) - .*/\1/p' "$SRC/CHANGELOG.md" | head -n 1)
check "VERSION is X.Y.Z" sh -c 'printf "%s" "$1" | grep -q -E "^[0-9]+\.[0-9]+\.[0-9]+$"' x "$v"
check "VERSION ($v) is the latest release in CHANGELOG.md ($top)" [ "$v" = "$top" ]
check "UPDATE.md has a step section for v$v" grep -q -x "### v$v" "$SRC/UPDATE.md"
tag=$(git -C "$SRC" tag -l 'v*' --sort=-v:refname | head -n 1)
if [ -n "$tag" ] && [ "$tag" != "v$v" ]; then
  check "VERSION ($v) is newer than the latest tag ($tag)" sh -c '[ "$(printf "%s\n%s\n" "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)" = "$1" ]' x "$v" "${tag#v}"
fi
if [ "$tag" = "v$v" ]; then
  check "the tag v$v has the same VERSION" [ "$(git -C "$SRC" show "$tag:VERSION")" = "$v" ]
fi

finish
