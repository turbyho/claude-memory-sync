#!/bin/sh
# After a migration: point the memory symlinks of this machine to the personal memory in
# the new repositories.
#
# Usage: tools/relink.sh <old repo path> <new main repo path> <user>
#
# Each symlink ~/.claude/projects/*/memory -> <old repo path>/projects/<name> or
# -> <new main repo path>/projects/<name> (the old symlink after the clone of the new
# repository at the same path) becomes a
# symlink to <repo>/projects/<name>/users/<user>, where <repo> is the new main repository
# or a project repository in ~/.claude/claude-memory.d/ (CLAUDE_MEMORY_EXTRA) that has
# the project. Run "sync.sh pull < /dev/null" first: it clones the project repositories.
# A symlink to a project that no new repository has stays as it is.
OLD=${1:?Usage: tools/relink.sh <old repo path> <new main repo path> <user>}
NEW=${2:?Usage: tools/relink.sh <old repo path> <new main repo path> <user>}
ME=${3:?Usage: tools/relink.sh <old repo path> <new main repo path> <user>}
EXTRA=${CLAUDE_MEMORY_EXTRA:-$HOME/.claude/claude-memory.d}
bad=0
for m in "$HOME"/.claude/projects/*/memory; do
  [ -L "$m" ] || continue
  t=$(readlink "$m")
  t=${t%/}
  # The symlinks are absolute. After "mv <new> <old>" and a clone of the new repository
  # at the same path, a symlink of the old layout points to <new>/projects/<name>: the
  # project directory of the new repository, not the personal memory in it.
  case $t in
    "$OLD/projects/"*) name=${t#"$OLD/projects/"} ;;
    "$NEW/projects/"*) name=${t#"$NEW/projects/"} ;;
    *) continue ;;
  esac
  case $name in
    */*) continue ;;
  esac
  new=""
  for r in "$NEW" "$EXTRA"/*; do
    if [ -d "$r/projects/$name/users/$ME" ]; then
      new="$r/projects/$name/users/$ME"
      break
    fi
  done
  if [ -n "$new" ]; then
    rm "$m"
    ln -s "$new" "$m"
    echo "relinked: $name -> $new"
  else
    echo "NOT IN A NEW REPOSITORY: $name ($m unchanged)"
    bad=1
  fi
done
exit $bad
