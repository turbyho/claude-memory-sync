#!/bin/sh
# Validate a memory repository of claude-memory-sync.
#
# Usage: tools/validate.sh <memory repo>
#
# Checks:
#   - Each link in MEMORY.md and hosts/<host>/INDEX.md goes to a file that exists.
#   - Each personal and local record has a line in its index.
#   - Each record has frontmatter with metadata.status and metadata.role.
#   - No team record or team shared topic has a forbidden pattern.
# Exit status 1 if a check fails.
R=${1:?Usage: tools/validate.sh <memory repo>}
cd "$R" || exit 1
bad=0
err() {
  echo "$*"
  bad=1
}

for idx in projects/*/users/*/MEMORY.md projects/*/users/*/hosts/*/INDEX.md; do
  [ -f "$idx" ] || continue
  d=$(dirname "$idx")
  # Links in code spans (`...`) are examples, not links.
  links=$(sed 's/`[^`]*`//g' "$idx" | grep -o -E '\]\([^)]+\.md\)' | sed 's/^](//; s/)$//')
  for t in $links; do
    case $t in
      "~/.claude/claude-memory/"*) p="$PWD/${t#\~/.claude/claude-memory/}" ;;
      *) p="$d/$t" ;;
    esac
    [ -f "$p" ] || err "BROKEN LINK: $idx -> $t"
  done
  for f in "$d"/*.md; do
    b=$(basename "$f")
    case $b in MEMORY.md|INDEX.md|*.*.md) continue ;; esac
    grep -q -F "]($b)" "$idx" || err "NO INDEX LINE: $d/$b"
  done
done

find projects users shared -name '*.md' ! -name MEMORY.md ! -name README.md ! -name INDEX.md \
  -type f 2>/dev/null | while IFS= read -r f; do
  case $f in projects/*/team/*) continue ;; esac
  awk 'NR == 1 && $0 != "---" { print "NO FRONTMATTER: " FILENAME; exit }
       NR > 1 && $0 == "---" { exit }
       /^  status:/ { s = 1 } /^  role:/ { r = 1 }
       END { if (NR > 1 && !(s && r)) print "NO STATUS OR ROLE: " FILENAME }' "$f"
done > "$R/.validate.tmp"
if [ -s "$R/.validate.tmp" ]; then
  cat "$R/.validate.tmp"
  bad=1
fi
rm -f "$R/.validate.tmp"

if [ -x ./sync.sh ]; then
  team=$(find projects/*/team shared -name '*.md' ! -name README.md -type f 2>/dev/null)
  if [ -n "$team" ]; then
    # shellcheck disable=SC2086
    out=$(./sync.sh lint $team) || { echo "$out" | sed 's/^/FORBIDDEN: /'; bad=1; }
  fi
fi

if [ $bad -eq 0 ]; then
  echo "OK: $(find projects users shared -name '*.md' ! -name MEMORY.md ! -name README.md ! -name INDEX.md -type f 2>/dev/null | wc -l | tr -d ' ') records, no problems."
fi
exit $bad
