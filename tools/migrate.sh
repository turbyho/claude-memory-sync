#!/bin/sh
# Migrate a memory repository of the old layout to the roles of claude-memory-sync.
#
# Old layout:  projects/<name>/MEMORY.md and records, and shared directories at the root
#              (for example ha/) that the projects link with a symlink <dir> -> ../../<dir>.
# New layout:  projects/<name>/users/<user>/       personal memory
#              projects/<name>/users/<user>/hosts/<host>/   local memory (--local)
#              projects/<name>/team/                team memory (empty)
#              users/<user>/shared/<dir>/           personal shared topic for each shared dir
#
# Usage:
#   tools/migrate.sh --old <old repo> --new <new repo> --user <user> --host <host>
#                    [--local <file>] [--status verified|confirmed|tentative] [--date YYYY-MM-DD]
#
#   --old     Working tree of the old repository. The script only reads it.
#   --new     Clone of the new memory repository (a copy of the template). The script
#             writes projects/ and users/ in it. It does not commit.
#   --user    Person name: the output of "sync.sh user" on a machine of the person.
#   --host    Machine name for --local: the output of "sync.sh host".
#   --local   File with one line "<project>/<file>.md" for each record that goes into
#             the local memory of --host. tools/local-candidates.sh helps to find them.
#   --status  State of the records: "verified" (default) gives "confirmed" to the
#             records with metadata.verified, and "tentative" to the other records.
#   --date    Date of the history line. Default: today.
#
# After the migration: run tools/validate.sh, read the result, then commit and push.
set -e

OLD="" NEW="" ME="" HOST="" LOCALS="" STATUS=verified TODAY=$(date +%Y-%m-%d)
while [ $# -gt 0 ]; do
  case $1 in
    --old) OLD=$2; shift 2 ;;
    --new) NEW=$2; shift 2 ;;
    --user) ME=$2; shift 2 ;;
    --host) HOST=$2; shift 2 ;;
    --local) LOCALS=$2; shift 2 ;;
    --status) STATUS=$2; shift 2 ;;
    --date) TODAY=$2; shift 2 ;;
    *) sed -n '2,30s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
  esac
done
if [ -z "$OLD" ] || [ -z "$NEW" ] || [ -z "$ME" ] || [ -z "$HOST" ]; then
  sed -n '2,30s/^# \{0,1\}//p' "$0" >&2
  exit 2
fi
case $STATUS in verified|confirmed|tentative) ;; *) echo "migrate.sh: bad --status" >&2; exit 2 ;; esac
[ -d "$OLD/projects" ] || { echo "migrate.sh: $OLD has no projects/" >&2; exit 1; }
TPL="$NEW/skills/memory-lifecycle/templates"
[ -f "$TPL/MEMORY.md" ] || { echo "migrate.sh: $NEW is not a copy of the template" >&2; exit 1; }
[ -n "$LOCALS" ] && [ ! -f "$LOCALS" ] && { echo "migrate.sh: no file $LOCALS" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The shared directories of the old layout: directories at the root with records.
SHARED=""
for d in "$OLD"/*/; do
  b=$(basename "$d")
  [ "$b" = projects ] && continue
  ls "$d"*.md >/dev/null 2>&1 && SHARED="$SHARED $b"
done

is_local() {
  [ -n "$LOCALS" ] && grep -q -x -F "$1" "$LOCALS"
}

state_of() {
  case $STATUS in
    confirmed|tentative) echo "$STATUS"; return ;;
  esac
  if awk 'NR == 1 { next } $0 == "---" { exit } /^  verified:/ { f = 1 } END { exit !f }' "$1"; then
    echo confirmed
  else
    echo tentative
  fi
}

# Copy a record, and add status, role and history to its metadata block. A record
# without frontmatter is copied without a change, with a warning.
convert_record() {
  src=$1 dst=$2 st=$3 role=$4
  if [ "$(head -n 1 "$src")" != "---" ]; then
    cp "$src" "$dst"
    echo "WARNING: no frontmatter, copied without a change: $src" >&2
    return
  fi
  awk -v st="$st" -v role="$role" -v line="$TODAY $ME@$HOST migrated" '
    function add() {
      if (!meta) print "metadata:"
      print "  status: " st
      print "  role: " role
      print "  history:"
      print "    - " line
      done = 1
    }
    NR == 1 { print; next }
    !done && inmeta && /^[^ ]/ { add(); inmeta = 0 }
    !done && $0 == "---" { add() }
    !done && /^metadata:/ { meta = 1; inmeta = 1 }
    { sub(/[ \t]+$/, ""); print }
  ' "$src" > "$dst"
}

# Index lines of a section: $1 = table (file TAB status TAB topic TAB line), $2 = status.
section_lines() {
  awk -F '\t' -v s="$2" '
    $2 == s {
      if ($3 != topic) { if ($3 != "") printf "### %s\n\n", $3; topic = $3 }
      print $4
      n++
    }
    END { if (n) print "" }' "$1"
}

count=0
for pdir in "$OLD"/projects/*/; do
  p=$(basename "$pdir")
  udir="$NEW/projects/$p/users/$ME"
  if [ -e "$udir" ]; then
    echo "migrate.sh: $udir exists. Stop." >&2
    exit 1
  fi
  mkdir -p "$udir/invalid" "$NEW/projects/$p/team"
  [ -f "$NEW/projects/$p/team/README.md" ] ||
    printf '# Team memory: %s\n\nRules: skill memory-lifecycle, section "Team memory".\n' "$p" \
      > "$NEW/projects/$p/team/README.md"
  cp "$TPL/INVALID-INDEX.md" "$udir/invalid/INDEX.md"
  : > "$WORK/personal"; : > "$WORK/local"; : > "$WORK/kept"; : > "$WORK/groups"

  # Read the old index: topic headings, index lines, other text.
  if [ -f "$pdir/MEMORY.md" ]; then
    topic=""
    while IFS= read -r l; do
      case $l in
        "# "*|"") continue ;;
        "## "*) topic=${l#\#\# }; continue ;;
        "- ["*"]("*")"*)
          f=$(printf '%s' "$l" | sed 's/^- \[[^]]*\](\([^)]*\)).*/\1/')
          sd=${f%%/*}
          if [ "$sd" != "$f" ] && printf ' %s ' "$SHARED " | grep -q " $sd "; then
            printf '%s\n' "$l" |
              sed "s|](\(${sd}\)/|](~/.claude/claude-memory/users/$ME/shared/\1/|; s|^- |  - |" >> "$WORK/groups.$sd"
            continue
          fi
          if [ ! -f "$pdir/$f" ]; then
            echo "WARNING: $p/MEMORY.md links a missing file: $f" >&2
            continue
          fi
          st=$(state_of "$pdir/$f")
          if is_local "$p/$f"; then
            printf '%s\t%s\t%s\t%s\n' "$f" "$st" "$topic" "$l" >> "$WORK/local"
          else
            printf '%s\t%s\t%s\t%s\n' "$f" "$st" "$topic" "$l" >> "$WORK/personal"
          fi ;;
        *)
          # Drop the old notes about a shared directory, keep other text.
          drop=0
          for sd in $SHARED; do
            case $l in *"$sd/"*) drop=1 ;; esac
          done
          [ $drop -eq 1 ] || printf '%s\n' "$l" >> "$WORK/kept" ;;
      esac
    done < "$pdir/MEMORY.md"
  fi

  for sd in $SHARED; do
    [ -f "$WORK/groups.$sd" ] || continue
    keys=$(sed 's/^  - \[\([^]]*\)\].*/\1/' "$WORK/groups.$sd" | paste -sd ',' - | sed 's/,/, /g')
    echo "- [$sd](~/.claude/claude-memory/users/$ME/shared/$sd/) - personal shared topic: $keys" >> "$WORK/groups"
    cat "$WORK/groups.$sd" >> "$WORK/groups"
    echo "$p" >> "$WORK/users.$sd"
    rm -f "$WORK/groups.$sd"
  done

  # Records. A record without an index line gets one from its description.
  for f in "$pdir"/*.md; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    [ "$b" = MEMORY.md ] && continue
    st=$(state_of "$f")
    if is_local "$p/$b"; then
      mkdir -p "$udir/hosts/$HOST"
      convert_record "$f" "$udir/hosts/$HOST/$b" "$st" local
      tbl=$WORK/local
    else
      convert_record "$f" "$udir/$b" "$st" personal
      tbl=$WORK/personal
    fi
    count=$((count + 1))
    if ! grep -q -F "]($b)" "$WORK/personal" "$WORK/local"; then
      ds=$(sed -n 's/^description: *//p' "$f" | head -n 1 | sed 's/^"//; s/"$//')
      printf '%s\t%s\t%s\t- [%s](%s) - %s\n' "$b" "$st" "" "${b%.md}" "$b" "$ds" >> "$tbl"
      echo "NOTE: $p/$b had no index line; made one from its description." >&2
    fi
  done

  # The new personal index.
  {
    sed "s/<!-- last-review: never -->/<!-- last-review: $TODAY -->/" "$TPL/MEMORY.md" |
      awk '/^## Confirmed/ { exit } { print }'
    if [ -s "$WORK/kept" ]; then cat "$WORK/kept"; echo; fi
    echo "## Confirmed"; echo
    section_lines "$WORK/personal" confirmed
    echo "## Tentative"; echo
    section_lines "$WORK/personal" tentative
    echo "## Groups"; echo
    if [ -s "$WORK/groups" ]; then cat "$WORK/groups"; echo; fi
    awk '/^## Invalid/ { f = 1 } f' "$TPL/MEMORY.md"
  } > "$udir/MEMORY.md"

  # The local index.
  if [ -s "$WORK/local" ]; then
    {
      sed "s/<host>/$HOST/" "$TPL/LOCAL-INDEX.md" | awk '/^## Confirmed/ { exit } { print }'
      echo "## Confirmed"; echo
      section_lines "$WORK/local" confirmed
      echo "## Tentative"; echo
      section_lines "$WORK/local" tentative
      echo "## Invalid"
    } > "$udir/hosts/$HOST/INDEX.md"
  fi
done

# Shared directories -> personal shared topics.
for sd in $SHARED; do
  tdir="$NEW/users/$ME/shared/$sd"
  mkdir -p "$tdir/invalid"
  for f in "$OLD/$sd"/*.md; do
    b=$(basename "$f")
    [ "$b" = README.md ] && continue
    convert_record "$f" "$tdir/$b" "$(state_of "$f")" personal
    count=$((count + 1))
  done
  {
    echo "# Personal shared topic: $sd"
    echo
    echo "Migrated from the shared directory $sd/ of the old layout. Rules: skill"
    echo "memory-lifecycle, section \"Shared topics\"."
    echo
    echo "Projects that use this topic (one line in \`## Groups\` of their MEMORY.md):"
    echo
    if [ -f "$WORK/users.$sd" ]; then
      sed 's|^|- projects/|; s|$|/|' "$WORK/users.$sd"
    fi
  } > "$tdir/README.md"
done

echo "Migrated $count records of $(ls -d "$OLD"/projects/*/ | wc -l | tr -d ' ') projects."
[ -n "$SHARED" ] && echo "Shared directories -> personal shared topics:$SHARED"
echo "Next: tools/validate.sh $NEW"
