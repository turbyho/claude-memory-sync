#!/bin/sh
# After a migration: point the memory symlinks of this machine to the personal memory in
# the new repository.
#
# Usage: tools/relink.sh <old repo path> <new repo path> <user>
#
# Each symlink ~/.claude/projects/*/memory -> <old repo path>/projects/<name> becomes
# ~/.claude/projects/*/memory -> <new repo path>/projects/<name>/users/<user>.
# A symlink to a project that the new repository does not have stays as it is.
OLD=${1:?Usage: tools/relink.sh <old repo path> <new repo path> <user>}
NEW=${2:?Usage: tools/relink.sh <old repo path> <new repo path> <user>}
ME=${3:?Usage: tools/relink.sh <old repo path> <new repo path> <user>}
for m in "$HOME"/.claude/projects/*/memory; do
  [ -L "$m" ] || continue
  t=$(readlink "$m")
  case $t in
    "$OLD/projects/"*) ;;
    *) continue ;;
  esac
  name=${t#"$OLD/projects/"}
  name=${name%/}
  new="$NEW/projects/$name/users/$ME"
  if [ -d "$new" ]; then
    rm "$m"
    ln -s "$new" "$m"
    echo "relinked: $name"
  else
    echo "NOT IN THE NEW REPOSITORY: $name ($m unchanged)"
  fi
done
