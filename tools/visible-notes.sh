#!/bin/sh
# Make the notes in the MEMORY.md files of a memory repository visible to Claude.
#
# Claude Code removes block-level HTML comments before it loads MEMORY.md. Thus Claude
# did not see "<!-- last-review: ... -->" and the rules line of releases before v0.3.1.
# This script replaces them with visible lines:
#   <!-- last-review: X -->                ->  Last review: X
#   <!-- Rules: skill memory-lifecycle ... --> and
#   <!-- Records for one machine only: ... -->  ->  one line "Rules: ..."
# A file without these comments does not change. You can run the script again.
#
# Usage: tools/visible-notes.sh <memory repo>
R=${1:?Usage: tools/visible-notes.sh <memory repo>}
RULES='Rules: skill memory-lifecycle. One line for each record or group. Records for one machine: hosts/<host>/INDEX.md (the SessionStart hook loads it).'
n=0
for f in "$R"/projects/*/users/*/MEMORY.md; do
  [ -f "$f" ] || continue
  grep -q -E '^<!-- (last-review:|Rules: skill memory-lifecycle|Records for one machine only:)' "$f" || continue
  awk -v rules="$RULES" '
    /^<!-- last-review: .* -->$/ {
      sub(/^<!-- last-review: /, ""); sub(/ -->$/, "")
      print "Last review: " $0
      if (!r) { print rules; r = 1 }
      next
    }
    /^<!-- Rules: skill memory-lifecycle.*-->$/ { if (!r) { print rules; r = 1 }; next }
    /^<!-- Records for one machine only:.*-->$/ { next }
    /^Rules: skill memory-lifecycle/ { if (r) next; r = 1 }
    { print }
  ' "$f" > "$f.new" && mv "$f.new" "$f"
  n=$((n + 1))
  echo "changed: ${f#"$R"/}"
done
echo "$n file(s) changed."
