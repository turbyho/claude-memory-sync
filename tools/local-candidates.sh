#!/bin/sh
# Show the records that can be local memory: records with an absolute path, a path in
# the home directory, a device or a system directory. Use the output to write the file
# for "tools/migrate.sh --local". Read each record: only a record that describes one
# machine is local. A general fact with a path as an example stays personal.
#
# Usage: tools/local-candidates.sh <repo>
#   <repo> is an old repository (projects/<name>/*.md) or a new one.
R=${1:?Usage: tools/local-candidates.sh <repo>}
TOOL=$(cd "$(dirname "$0")/.." && pwd)
P=$(sed '/^#/d;/^[[:space:]]*$/d' "$TOOL/team-memory-check.default" | paste -sd '|' -)
P="$P|(^|[ \`(])/(opt|srv|var|etc|usr/local|dev)/"
cd "$R" || exit 1
find projects -name '*.md' ! -name MEMORY.md ! -name INDEX.md ! -name README.md -type f |
  LC_ALL=C sort | while IFS= read -r f; do
  m=$(grep -n -E -- "$P" "$f" | head -n 4 | cut -c1-150)
  [ -n "$m" ] || continue
  # Old layout: projects/<name>/<file>.md; new layout: projects/<name>/users/<user>/<file>.md
  p=$(echo "$f" | cut -d/ -f2)
  echo "#### $p/$(basename "$f")"
  sed -n 's/^description: *//p' "$f" | head -n 1 | cut -c1-200
  printf '%s\n' "$m" | sed 's/^/    /'
done
