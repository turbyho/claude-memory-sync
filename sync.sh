#!/bin/sh
# claude-memory-sync: keep the Claude Code auto memory in one git repository, and sync it
# between machines and persons. POSIX sh (macOS and Linux).
#
# Roles of the memory of a project, in projects/<name>/:
#   team/                    team memory: facts for all persons
#   users/<user>/            personal memory of one person, on all machines of the person
#   users/<user>/hosts/<h>/  local memory: facts for one machine of the person
#
#   sync.sh pull             SessionStart hook. Pull the repository, then link the memory
#                            of the session. The hook gives {"cwd": ...} on stdin. The
#                            output (local and team memory) goes into the context of Claude.
#   sync.sh push             Stop hook. Commit the local changes and push them.
#   sync.sh check-team       PreToolUse hook. Block a write into the team memory that
#                            contains a forbidden pattern.
#   sync.sh enable [dir]     Enable the memory of the project in dir for this person.
#   sync.sh disable [dir]    Disable the personal memory of the project for this person.
#   sync.sh lint <file>...   Show the forbidden patterns in team memory files.
#   sync.sh status [dir]     Show the name and the state of the project.
#   sync.sh list             Show the projects and the persons that use them.
#   sync.sh user             Show the name of this person, as the memory uses it.
#   sync.sh host             Show the name of this machine, as the memory uses it.
#
# The default dir is the current directory.
# The script ignores network errors. Without the server, Claude uses the local copy.

REPO=${CLAUDE_MEMORY_REPO:-$(cd "$(dirname "$0")" && pwd)}
PROJECTS="$HOME/.claude/projects"
BACKUP="$HOME/.claude/memory-backup"
TEMPLATES="$REPO/skills/memory-lifecycle/templates"
LOCAL_LINES=100
TEAM_LINES=150
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"

# Make a name safe for a directory: lower case, other characters than a-z 0-9 . _ - become
# "-".
safe_name() {
  printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C sed 's/[^a-z0-9._-]/-/g'
}

# Name of this machine. It must not change, because the local memory is in
# hosts/<name>/. On macOS, "hostname -s" can change with the network, thus use the
# LocalHostName. The env var CLAUDE_MEMORY_HOST overrides the name.
host_name() {
  if [ -n "$CLAUDE_MEMORY_HOST" ]; then
    echo "$CLAUDE_MEMORY_HOST"
  elif command -v scutil >/dev/null 2>&1 && scutil --get LocalHostName 2>/dev/null; then
    :
  else
    hostname -s 2>/dev/null || hostname
  fi
}

# Name of this person: the part before "@" of the git user.email of the repository. It
# must be the same on all machines of the person. The env var CLAUDE_MEMORY_USER
# overrides the name.
user_name() {
  u=$CLAUDE_MEMORY_USER
  [ -n "$u" ] || u=$(git -C "$REPO" config user.email 2>/dev/null | sed 's/@.*//')
  [ -n "$u" ] || u=${USER:-$(id -un)}
  safe_name "$u"
}

HOST=$(host_name)
ME=$(user_name)
START=$PWD
cd "$REPO" || exit 0

# Read one field of the JSON hook input. $1 is the JSON text, $2 a jq expression, $3 the
# same expression in Python (the variable d is the parsed input).
json_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r "$2 // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c "import json,sys; d=json.load(sys.stdin); v=$3; print(v if v else '')" 2>/dev/null
  else
    return 1
  fi
}

# Read the "cwd" field of the hook input on stdin.
read_cwd() {
  input=$(cat)
  json_field "$input" '.cwd' 'd.get("cwd","")' ||
    printf '%s' "$input" | sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p'
}

# Absolute physical path of a directory. Claude Code uses this form for the slug.
abs_dir() {
  (cd "$1" 2>/dev/null && pwd -P)
}

# Name of the project in the repository. It does not depend on the path, thus it is the
# same on each machine and for each person: the name of the git remote "origin", else
# the name of the git top directory, else the name of the directory. The home directory
# is "_home".
project_name() {
  dir=$1
  if [ "$dir" = "$HOME" ] || [ "$dir" = "$(abs_dir "$HOME")" ]; then
    echo "_home"
    return
  fi
  url=$(git -C "$dir" remote get-url origin 2>/dev/null)
  if [ -n "$url" ]; then
    name=$(basename "$url" .git)
  else
    name=$(basename "$(project_root "$dir")")
  fi
  echo "$name"
}

# Directory from which Claude Code makes the slug. In git, this is the top directory of
# the main working tree, thus a subdirectory and each worktree use the same memory.
# Outside git, this is the directory itself.
project_root() {
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ "$(basename "$common")" = ".git" ]; then
    abs_dir "$(dirname "$common")"
    return
  fi
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)
  abs_dir "${top:-$1}"
}

# Memory directory of the project in a directory. Claude Code makes the slug from the
# path: each character other than A-Z a-z 0-9 becomes "-". LC_ALL=C is necessary: in
# some locales (for example cs_CZ), sed reads "ch" as one character.
memory_dir() {
  if [ "$(project_name "$1")" = "_home" ]; then
    root=$(abs_dir "$1")
  else
    root=$(project_root "$1")
  fi
  echo "$PROJECTS/$(printf '%s' "$root" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')/memory"
}

# Link the memory directory of a session to the personal memory in the repository. If a
# local memory directory exists, copy its files into the repository first. If a file is
# different in the two places, keep the local version as <file>.<host>.md.
link() {
  mem=$1
  dst=$2
  [ -L "$mem" ] && return 0
  if [ -d "$mem" ]; then
    for f in "$mem"/* "$mem"/.[!.]*; do
      [ -e "$f" ] || continue
      fname=$(basename "$f")
      if [ ! -e "$dst/$fname" ]; then
        cp -R "$f" "$dst/$fname"
      elif ! cmp -s "$f" "$dst/$fname"; then
        cp -R "$f" "$dst/${fname%.md}.$HOST.md"
      fi
    done
    mkdir -p "$BACKUP"
    mv "$mem" "$BACKUP/$(basename "$(dirname "$mem")").$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$(dirname "$mem")"
  ln -s "$dst" "$mem"
}

# Replace the symlink of a session with a local copy of the memory. $3 is the path of the
# personal memory in the repository, relative to the root.
unlink_copy() {
  mem=$1
  src=$2
  rel=$3
  rm "$mem"
  mkdir -p "$mem"
  if [ -d "$src" ]; then
    cp -RL "$src/." "$mem/"
  else
    # A different machine disabled the memory. Get its last version from the git history.
    c=$(git rev-list -n 1 HEAD -- "$rel" 2>/dev/null)
    depth=$(printf '%s' "$rel" | awk -F / '{ print NF }')
    [ -n "$c" ] && git archive "$c^" "$rel" 2>/dev/null |
      tar -x -C "$mem" --strip-components="$depth"
  fi
}

# Write a warning to stdout if the repository has a rebase that stopped on a conflict.
# The SessionStart hook gives the text to Claude, and Claude tells the user.
conflict_warning() {
  for d in rebase-merge rebase-apply; do
    p=$(git rev-parse --git-path "$d" 2>/dev/null) || continue
    if [ -d "$p" ]; then
      echo "WARNING: the memory repository $REPO has a rebase conflict. The sync stopped."
      echo "Tell the user. See README.md, section \"Conflicts\"."
      echo
      return
    fi
  done
}

# Write the local memory of this machine to stdout. The SessionStart hook gives this text
# to Claude, thus the local index does not use the space of MEMORY.md.
local_context() {
  mem=$1
  dst=$2
  [ "$(readlink "$mem")" = "$dst" ] || return 0
  echo "Local memory of this machine ($HOST): $mem/hosts/$HOST/"
  echo "Records there apply only to this machine. They can contain absolute paths and"
  echo "links outside the project. Rules: skill memory-lifecycle, section \"Roles\"."
  idx="$dst/hosts/$HOST/INDEX.md"
  if [ -f "$idx" ]; then
    echo
    head -n "$LOCAL_LINES" "$idx"
    if [ "$(wc -l < "$idx")" -gt "$LOCAL_LINES" ]; then
      echo "(INDEX.md has more than $LOCAL_LINES lines. Read the full file.)"
    fi
  else
    echo "It is empty."
  fi
  echo
}

# One line for each record in directory $1: <status> TAB <path> TAB <name> TAB
# <description>. The script reads the frontmatter. A record in invalid/ is "invalid". A
# record without a status is "tentative".
records() {
  find "$1" -type f -name '*.md' ! -name README.md | LC_ALL=C sort | while IFS= read -r f; do
    rel=${f#"$1"/}
    awk -v rel="$rel" '
      NR == 1 && $0 != "---" { exit }
      NR > 1 && $0 == "---" {
        if (rel ~ /^invalid\//) st = "invalid"
        if (st == "") st = "tentative"
        printf "%s\t%s\t%s\t%s\n", st, rel, nm, ds
        exit
      }
      /^name:/ { sub(/^name:[ ]*/, ""); nm = $0 }
      /^description:/ { sub(/^description:[ ]*/, ""); ds = $0 }
      /^[ ]+status:/ { sub(/^[ ]+status:[ ]*/, ""); sub(/[ ]*#.*/, ""); st = $0 }
    ' "$f"
  done
}

# Write the team memory of a project to stdout: an index made from the frontmatter of the
# records. The team memory has no INDEX.md, thus two persons cannot get a conflict in it.
team_context() {
  tdir="$REPO/projects/$1/team"
  [ -d "$tdir" ] || return 0
  echo "Team memory of this project (all persons see it): $tdir/"
  echo "Write a record there only with the approval of the user. No absolute paths, no"
  echo "host names, no links outside the project. Rules: skill memory-lifecycle, section"
  echo "\"Team memory\"."
  tmp=$(mktemp) || return 0
  records "$tdir" > "$tmp" 2>/dev/null
  {
    for st in confirmed tentative invalid; do
      case $st in
        confirmed) title="## Confirmed" ;;
        tentative) title="## Tentative" ;;
        invalid) title="## Invalid (known false or outdated claims; never use them as facts)" ;;
      esac
      lines=$(awk -F '\t' -v s="$st" '$1 == s { printf "- [%s](%s) - %s\n", $3, $2, $4 }' "$tmp")
      [ -n "$lines" ] || continue
      echo
      echo "$title"
      echo "$lines"
    done
  } | head -n "$TEAM_LINES"
  [ -s "$tmp" ] || echo "It is empty."
  rm -f "$tmp"
  echo
}

# The forbidden patterns of the team memory, as one extended regular expression. The team
# can change them in .memory-check in the root of the repository: one pattern on each
# line, "#" starts a comment line.
team_patterns() {
  f="$REPO/.memory-check"
  [ -f "$f" ] || f="$REPO/team-memory-check.default"
  sed '/^#/d;/^[[:space:]]*$/d' "$f" | paste -sd '|' -
}

# Is a path (relative to the repository) team memory?
is_team_path() {
  case $1 in
    projects/*/team/*.md|shared/*.md) return 0 ;;
  esac
  return 1
}

# Show the lines of the files that contain a forbidden pattern. Exit status 1 if there is
# one or more.
lint() {
  pat=$(team_patterns)
  [ -n "$pat" ] || return 0
  bad=0
  for f in "$@"; do
    [ -f "$f" ] || continue
    m=$(grep -n -E -- "$pat" "$f")
    if [ -n "$m" ]; then
      printf '%s\n' "$m" | sed "s|^|$f:|"
      bad=1
    fi
  done
  return $bad
}

# Write a warning to stdout for each team memory file that is not committed because it
# contains a forbidden pattern.
lint_warning() {
  out=$(git status --porcelain --untracked-files=all 2>/dev/null | sed -n 's/^.. //p' |
    while IFS= read -r f; do
      is_team_path "$f" && lint "$f"
    done)
  [ -n "$out" ] || return 0
  echo "WARNING: these team memory files are not committed, because they contain a"
  echo "forbidden pattern (absolute path, home directory, link outside the project)."
  echo "Tell the user. Move the machine detail to the local memory, then fix the file:"
  echo "$out" | head -n 20
  echo
}

# Commit and push. A team memory file with a forbidden pattern stays out of the commit.
# The next SessionStart shows it to Claude.
push() {
  git add -A >/dev/null 2>&1
  git diff --cached --name-only --diff-filter=AM | while IFS= read -r f; do
    is_team_path "$f" || continue
    lint "$f" >/dev/null || git reset -q -- "$f"
  done
  if ! git diff --cached --quiet; then
    git commit -q -m "${1:-Update memory from $ME@$HOST}" >/dev/null 2>&1
  fi
  if ! git rev-parse -q --verify '@{u}' >/dev/null 2>&1 || [ -n "$(git log '@{u}..' --oneline 2>/dev/null)" ]; then
    git pull -q --rebase --autostash >/dev/null 2>&1
    git push -q -u origin HEAD >/dev/null 2>&1
  fi
}

# Set dir, name, mem, pdir (the project) and udir (the personal memory) from a directory.
target() {
  dir=$(abs_dir "${1:-.}")
  if [ -z "$dir" ]; then
    echo "sync.sh: not a directory: ${1:-.}" >&2
    exit 1
  fi
  name=$(project_name "$dir")
  mem=$(memory_dir "$dir")
  pdir="$REPO/projects/$name"
  udir="$pdir/users/$ME"
}

# Wait until no other git command uses the repository (for example the async push of the
# last reply). Maximum 10 seconds.
wait_for_lock() {
  lock=$(git rev-parse --git-path index.lock 2>/dev/null)
  i=0
  while [ -e "$lock" ] && [ $i -lt 10 ]; do
    sleep 1
    i=$((i + 1))
  done
}

case "$1" in
  pull)
    dir=$(read_cwd)
    wait_for_lock
    git pull -q --rebase --autostash >/dev/null 2>&1
    conflict_warning
    lint_warning
    [ -n "$dir" ] && [ -d "$dir" ] || exit 0
    target "$dir"
    if [ -L "$mem" ] && [ ! -e "$mem" ] && [ "$(readlink "$mem")" = "$udir" ]; then
      unlink_copy "$mem" "$udir" "projects/$name/users/$ME"
    elif [ -d "$udir" ]; then
      link "$mem" "$udir"
      local_context "$mem" "$udir"
    fi
    team_context "$name"
    ;;
  push)
    push
    ;;
  check-team)
    input=$(cat)
    file=$(json_field "$input" '.tool_input.file_path' 'd.get("tool_input",{}).get("file_path","")') || exit 0
    rel=""
    for base in "$REPO" "$(abs_dir "$REPO")"; do
      case $file in "$base"/*) rel=${file#"$base"/} ;; esac
    done
    [ -n "$rel" ] && is_team_path "$rel" || exit 0
    text=$(json_field "$input" \
      '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' \
      '"\n".join([x for x in [d["tool_input"].get("content"), d["tool_input"].get("new_string")] + [e.get("new_string") for e in d["tool_input"].get("edits", [])] if x])')
    pat=$(team_patterns)
    [ -n "$pat" ] || exit 0
    found=$(printf '%s\n' "$text" | grep -n -E -- "$pat" | head -n 5)
    if [ -n "$found" ]; then
      echo "Blocked: the team memory must not contain absolute paths, home directory paths," >&2
      echo "or links outside the project. Put the machine detail into the local memory," >&2
      echo "and write only the general fact into the team memory. Lines:" >&2
      echo "$found" >&2
      exit 2
    fi
    ;;
  enable)
    target "$2"
    if [ ! -d "$pdir/team" ]; then
      mkdir -p "$pdir/team"
      printf '# Team memory: %s\n\nRules: skill memory-lifecycle, section "Team memory".\n' \
        "$name" > "$pdir/team/README.md"
    fi
    mkdir -p "$udir"
    link "$mem" "$udir"
    if [ ! -e "$udir/MEMORY.md" ]; then
      if [ -f "$TEMPLATES/MEMORY.md" ]; then
        cp "$TEMPLATES/MEMORY.md" "$udir/MEMORY.md"
        mkdir -p "$udir/invalid"
        cp "$TEMPLATES/INVALID-INDEX.md" "$udir/invalid/INDEX.md"
      else
        : > "$udir/MEMORY.md"
      fi
    fi
    push "Enable memory of $name for $ME"
    echo "Enabled: $name for $ME"
    echo "  $mem -> $udir"
    ;;
  disable)
    target "$2"
    if [ ! -d "$udir" ]; then
      echo "Not enabled: $name for $ME"
      exit 0
    fi
    for m in "$PROJECTS"/*/memory; do
      [ -L "$m" ] && [ "$(readlink "$m")" = "$udir" ] &&
        unlink_copy "$m" "$udir" "projects/$name/users/$ME"
    done
    git rm -r -q --ignore-unmatch "projects/$name/users/$ME" >/dev/null 2>&1
    rm -rf "$udir"
    push "Disable memory of $name for $ME"
    echo "Disabled: $name for $ME"
    echo "  Your memory stays as a local copy in $PROJECTS/*/memory on this machine."
    echo "  Your other machines make a local copy at their next session in the project."
    echo "  The team memory and the memory of other persons do not change."
    ;;
  lint)
    shift
    cd "$START" || exit 1
    lint "$@" || exit 1
    ;;
  status)
    target "$2"
    echo "Project:    $name"
    echo "Person:     $ME"
    echo "Machine:    $HOST"
    if [ -d "$udir" ]; then
      echo "Personal:   enabled ($udir)"
    else
      echo "Personal:   disabled"
    fi
    if [ -L "$mem" ]; then
      echo "Memory:     $mem -> $(readlink "$mem")"
    elif [ -d "$mem" ]; then
      echo "Memory:     $mem (local directory)"
    else
      echo "Memory:     none"
    fi
    if [ -d "$pdir/team" ]; then
      echo "Team:       $pdir/team"
    else
      echo "Team:       none"
    fi
    ;;
  list)
    for p in "$REPO"/projects/*/; do
      [ -d "$p" ] || continue
      users=$(cd "$p" && ls users 2>/dev/null | tr '\n' ' ')
      echo "$(basename "$p"): ${users:-(no persons)}"
    done
    ;;
  user)
    echo "$ME"
    ;;
  host)
    echo "$HOST"
    ;;
  *)
    sed -n '2,26s/^# \{0,1\}//p' "$0" >&2
    exit 2
    ;;
esac
exit 0
