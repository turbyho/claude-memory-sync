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
#   sync.sh enable [dir] --repo <alias>
#                            Enable the project in a different memory repository.
#   sync.sh add-repo <alias> <url>
#                            Add a memory repository for some projects. Its clone is in
#                            ~/.claude/claude-memory.d/<alias>; all your machines get it.
#   sync.sh repos            Show the memory repositories and their projects.
#   sync.sh move [dir] <alias>
#                            Move the project (team and personal memory) to a different
#                            memory repository. "main" is ~/.claude/claude-memory.
#   sync.sh setup            Set up this machine: hooks, instructions, skill. Idempotent.
#   sync.sh update           Merge the latest release of claude-memory-sync from the remote
#                            "upstream", push it, then run setup.
#   sync.sh version          Show the version of the repository, of the latest release and
#                            of the setup of this machine.
#
# The default dir is the current directory.
# The script ignores network errors. Without the server, Claude uses the local copy.

REPO=${CLAUDE_MEMORY_REPO:-$(cd "$(dirname "$0")" && pwd)}
# Directory of the other memory repositories: one clone for each alias.
EXTRA=${CLAUDE_MEMORY_EXTRA:-$HOME/.claude/claude-memory.d}
PROJECTS="$HOME/.claude/projects"
BACKUP="$HOME/.claude/memory-backup"
TEMPLATES="$REPO/skills/memory-lifecycle/templates"
LOCAL_LINES=100
TEAM_LINES=150
# Version of the machine setup (hooks, instructions, skill) that this sync.sh needs.
# Increase it when a release changes the setup. "sync.sh setup" writes it to SETUP_FILE.
SETUP_VERSION=1
SETUP_FILE="$HOME/.claude/claude-memory-setup"
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"
export GIT_HTTP_LOW_SPEED_LIMIT=${GIT_HTTP_LOW_SPEED_LIMIT:-1000}
export GIT_HTTP_LOW_SPEED_TIME=${GIT_HTTP_LOW_SPEED_TIME:-5}

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

# The memory repositories: the main repository first, then each clone in EXTRA.
repos() {
  echo "$REPO"
  for d in "$EXTRA"/*/; do
    [ -d "$d.git" ] && echo "${d%/}"
  done
}

# Alias of a repository: "main" for the main repository, else the directory name.
repo_alias() {
  if [ "$1" = "$REPO" ]; then echo main; else basename "$1"; fi
}

# Path of the repository with an alias. Empty if there is no clone.
alias_path() {
  if [ "$1" = main ]; then
    echo "$REPO"
  elif [ -d "$EXTRA/$1/.git" ]; then
    echo "$EXTRA/$1"
  fi
}

# The repository that has the project $1 (projects/<name>/). The main repository first.
# Empty if no repository has it.
repo_of() {
  repos | while IFS= read -r r; do
    if [ -d "$r/projects/$1" ]; then
      echo "$r"
      break
    fi
  done
}

# The list of the other memory repositories of this person: users/<user>/repos.conf in
# the main repository, one line "<alias> <url>" for each repository.
REPOS_CONF="$REPO/users/$ME/repos.conf"

# Clone each repository of repos.conf that has no clone on this machine yet.
clone_missing() {
  [ -f "$REPOS_CONF" ] || return 0
  sed '/^#/d;/^[[:space:]]*$/d' "$REPOS_CONF" | while read -r a u; do
    [ -n "$a" ] && [ -n "$u" ] || continue
    [ -d "$EXTRA/$a/.git" ] && continue
    mkdir -p "$EXTRA"
    if git clone -q "$u" "$EXTRA/$a" >/dev/null 2>&1; then
      echo "NOTICE: cloned the memory repository \"$a\" to $EXTRA/$a."
      echo
    else
      rm -rf "$EXTRA/$a"
      echo "WARNING: cannot clone the memory repository \"$a\" ($u). The projects in it"
      echo "are not synced on this machine. Tell the user."
      echo
    fi
  done
}

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

# Copy the files of directory $1 into directory $2, with the subdirectories. A file that
# is only in $1 is copied. A file that is different in the two places is copied as
# <file>.<host>.md next to the file in $2.
merge_into() {
  for f in "$1"/* "$1"/.[!.]*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    if [ ! -e "$2/$b" ]; then
      cp -R "$f" "$2/$b"
    elif [ -d "$f" ] && [ -d "$2/$b" ]; then
      merge_into "$f" "$2/$b"
    elif [ -f "$f" ] && ! cmp -s "$f" "$2/$b"; then
      cp "$f" "$2/${b%.md}.$HOST.md"
    fi
  done
}

# Link the memory directory of a session to the personal memory in the repository. If a
# local memory directory exists, copy its files into the repository first. If a file is
# different in the two places, keep the local version as <file>.<host>.md.
link() {
  mem=$1
  dst=$2
  [ -L "$mem" ] && return 0
  if [ -d "$mem" ]; then
    merge_into "$mem" "$dst"
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
      echo "WARNING: the memory repository $PWD has a rebase conflict. The sync stopped."
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

# Write the team memory of project $1 in repository $2 to stdout: an index made from the
# frontmatter of the records. The team memory has no INDEX.md, thus two persons cannot
# get a conflict in it.
team_context() {
  tdir="$2/projects/$1/team"
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
# can change them in .memory-check in the root of the repository (the current directory):
# one pattern on each line, "#" starts a comment line.
team_patterns() {
  f="$PWD/.memory-check"
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
    git pull -q --rebase=merges --autostash >/dev/null 2>&1
    git push -q -u origin HEAD >/dev/null 2>&1
  fi
}

# Version of the tool in the repository. A repository without VERSION is older than the
# first release.
repo_version() {
  v=$(cat "$REPO/VERSION" 2>/dev/null)
  echo "${v:-0.0.0}"
}

# Is version $1 greater than version $2? Versions are X.Y.Z.
ver_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 1
  }'
}

# The latest release tag (vX.Y.Z) that git knows.
latest_tag() {
  git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n 1
}

# Get the release tags from the remote "upstream", at most one time in 24 hours.
fetch_releases() {
  git remote get-url upstream >/dev/null 2>&1 || return 0
  stamp="$(git rev-parse --git-dir 2>/dev/null)/claude-memory-sync-fetch"
  [ -n "$(find "$stamp" -mmin -1440 2>/dev/null)" ] && return 0
  git fetch -q --tags upstream >/dev/null 2>&1 && touch "$stamp"
}

# Write a notice to stdout if a newer release exists, or if the setup of this machine is
# older than this sync.sh needs. The SessionStart hook gives the text to Claude.
update_notice() {
  cur=$(repo_version)
  new=$(latest_tag)
  if [ -n "$new" ] && ver_gt "${new#v}" "$cur"; then
    echo "UPDATE: claude-memory-sync $new is available. This repository has v$cur."
    echo "Tell the user, then do the update. The update instructions of $new are in:"
    echo "  git -C $REPO show $new:UPDATE.md"
    echo
  fi
  have=$(cat "$SETUP_FILE" 2>/dev/null)
  if [ "${have:-0}" -lt "$SETUP_VERSION" ] 2>/dev/null; then
    echo "SETUP: the setup of this machine has version ${have:-0}, claude-memory-sync needs"
    echo "version $SETUP_VERSION. Tell the user, then run: $REPO/sync.sh setup"
    echo "Instructions: $REPO/UPDATE.md, section \"Setup of a machine\"."
    echo
  fi
}

# Path of sync.sh for the hook commands: with "~" if the repository is in the home
# directory.
hook_path() {
  case $REPO in
    "$HOME"/*) echo "~${REPO#"$HOME"}/sync.sh" ;;
    *) echo "$REPO/sync.sh" ;;
  esac
}

# Set up this machine: hooks in settings.json, import line in CLAUDE.md, skill symlink.
# Each step changes nothing if it is done already.
setup() {
  s="$HOME/.claude/settings.json"
  sh_path=$(hook_path)
  mkdir -p "$HOME/.claude"
  [ -f "$s" ] || echo '{}' > "$s"
  missing=""
  for c in pull push check-team; do
    grep -q "sync.sh $c\"" "$s" || missing="$missing $c"
  done
  if [ -n "$missing" ]; then
    b="$s.bak.$(date +%Y%m%d%H%M%S)"
    cp "$s" "$b"
    if command -v jq >/dev/null 2>&1; then
      prog="."
      for c in $missing; do
        case $c in
          pull) prog="$prog | .hooks.SessionStart += [{\"hooks\":[{\"type\":\"command\",\"command\":\"$sh_path pull\",\"timeout\":20}]}]" ;;
          push) prog="$prog | .hooks.Stop += [{\"hooks\":[{\"type\":\"command\",\"command\":\"$sh_path push\",\"timeout\":30,\"async\":true}]}]" ;;
          check-team) prog="$prog | .hooks.PreToolUse += [{\"matcher\":\"Write|Edit|MultiEdit\",\"hooks\":[{\"type\":\"command\",\"command\":\"$sh_path check-team\",\"timeout\":10}]}]" ;;
        esac
      done
      jq "$prog" "$b" > "$s.new"
    elif command -v python3 >/dev/null 2>&1; then
      python3 - "$b" "$s.new" "$sh_path" $missing <<'PY'
import json, sys
src, dst, path, missing = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
d = json.load(open(src))
h = d.setdefault("hooks", {})
spec = {
    "pull": ("SessionStart", {"hooks": [{"type": "command", "command": path + " pull", "timeout": 20}]}),
    "push": ("Stop", {"hooks": [{"type": "command", "command": path + " push", "timeout": 30, "async": True}]}),
    "check-team": ("PreToolUse", {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": path + " check-team", "timeout": 10}]}),
}
for m in missing:
    ev, entry = spec[m]
    h.setdefault(ev, []).append(entry)
json.dump(d, open(dst, "w"), indent=2)
PY
    else
      echo "sync.sh setup: jq or python3 is necessary to change $s." >&2
      return 1
    fi
    if [ -s "$s.new" ] && { ! command -v jq >/dev/null 2>&1 || jq empty "$s.new" 2>/dev/null; }; then
      mv "$s.new" "$s"
      echo "Hooks added:$missing (backup: $b)"
    else
      rm -f "$s.new"
      echo "sync.sh setup: the new settings.json is not valid. Nothing changed." >&2
      return 1
    fi
  else
    echo "Hooks: present"
  fi

  imp="@$(dirname "$sh_path")/CLAUDE-MEMORY.md"
  cm="$HOME/.claude/CLAUDE.md"
  if [ -f "$cm" ] && grep -q -F -x "$imp" "$cm"; then
    echo "Instructions: present"
  else
    [ -f "$cm" ] && cp "$cm" "$cm.bak.$(date +%Y%m%d%H%M%S)"
    printf '\n%s\n' "$imp" >> "$cm"
    echo "Instructions: import line added to $cm"
  fi

  sk="$HOME/.claude/skills/memory-lifecycle"
  if [ -L "$sk" ] && [ "$(readlink "$sk")" = "$REPO/skills/memory-lifecycle" ]; then
    echo "Skill: present"
  elif [ -e "$sk" ] || [ -L "$sk" ]; then
    echo "Skill: $sk exists and is not the symlink to $REPO/skills/memory-lifecycle. Not changed." >&2
  else
    mkdir -p "$HOME/.claude/skills"
    ln -s "$REPO/skills/memory-lifecycle" "$sk"
    echo "Skill: symlink made"
  fi

  echo "$SETUP_VERSION" > "$SETUP_FILE"
  echo "Setup version: $SETUP_VERSION"
}

# Merge the latest release from "upstream". Stop at a conflict, without a change.
update() {
  if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "sync.sh update: no remote \"upstream\". Add it: git -C $REPO remote add upstream <URL of claude-memory-sync>" >&2
    return 1
  fi
  wait_for_lock
  push "Update memory from $ME@$HOST"
  git pull -q --rebase=merges --autostash >/dev/null 2>&1
  if ! git fetch -q --tags upstream; then
    echo "sync.sh update: cannot get the releases from upstream." >&2
    return 1
  fi
  touch "$(git rev-parse --git-dir)/claude-memory-sync-fetch"
  cur=$(repo_version)
  new=$(latest_tag)
  if [ -z "$new" ] || ! ver_gt "${new#v}" "$cur"; then
    echo "Up to date: v$cur"
    return 0
  fi
  echo "Update: v$cur -> $new"
  echo "Changes (CHANGELOG.md):"
  git diff HEAD "$new" -- CHANGELOG.md | sed -n 's/^+\([^+]\)/  \1/p; s/^+$//p'
  if ! git merge -q --no-edit -m "Update claude-memory-sync to $new" "$new" >/dev/null 2>&1; then
    files=$(git diff --name-only --diff-filter=U)
    git merge --abort >/dev/null 2>&1
    echo "CONFLICT: the merge of $new stopped. Nothing changed. Files:" >&2
    echo "$files" | sed 's/^/  /' >&2
    echo "See $REPO/UPDATE.md, section \"Conflicts\"." >&2
    return 1
  fi
  push
  echo "Merged and pushed: $new"
  "$REPO/sync.sh" setup
}

# Set dir, name, mem, repo (the repository of the project), pdir (the project) and udir
# (the personal memory) from a directory. A project in no repository goes to the main
# repository.
target() {
  dir=$(abs_dir "${1:-.}")
  if [ -z "$dir" ]; then
    echo "sync.sh: not a directory: ${1:-.}" >&2
    exit 1
  fi
  name=$(project_name "$dir")
  mem=$(memory_dir "$dir")
  repo=$(repo_of "$name")
  [ -n "$repo" ] || repo=$REPO
  pdir="$repo/projects/$name"
  udir="$pdir/users/$ME"
}

# Wait until no other git command uses the repository in the current directory (for
# example the async push of the last reply). Maximum 10 seconds.
wait_for_lock() {
  lock=$(git rev-parse --git-path index.lock 2>/dev/null)
  i=0
  while [ -e "$lock" ] && [ $i -lt 10 ]; do
    sleep 1
    i=$((i + 1))
  done
}

# The symlink of the session points to a personal memory that does not exist any more.
# If the project is now in a different repository (sync.sh move), link it there. Else
# make a local copy from the git history (sync.sh disable), and tell why.
dangling() {
  old=$(readlink "$mem")
  if [ -d "$udir" ]; then
    rm "$mem"
    ln -s "$udir" "$mem"
    echo "NOTICE: the project $name is now in the memory repository \"$(repo_alias "$repo")\"."
    echo
    return
  fi
  repos | while IFS= read -r r; do
    case $old in
      "$r"/*)
        (
          cd "$r" || exit 0
          rel=${old#"$r"/}
          unlink_copy "$mem" "$old" "$rel"
          s=$(git log -1 --format=%s -- "projects/$name" 2>/dev/null)
          case $s in
            "Move project $name to "*)
              echo "WARNING: $s. This machine has no clone of that memory repository, thus"
              echo "the memory of $name is a local copy now. Tell the user: add the"
              echo "repository with sync.sh add-repo, then start a new session."
              echo
              ;;
          esac
        )
        break
        ;;
    esac
  done
}

case "$1" in
  pull)
    dir=$(read_cwd)
    # The main repository first: its repos.conf tells which other repositories to clone.
    wait_for_lock
    git pull -q --rebase=merges --autostash >/dev/null 2>&1
    conflict_warning
    lint_warning
    clone_missing
    repos | while IFS= read -r r; do
      [ "$r" = "$REPO" ] && continue
      (
        cd "$r" || exit 0
        wait_for_lock
        git pull -q --rebase=merges --autostash >/dev/null 2>&1
        conflict_warning
        lint_warning
      )
    done
    fetch_releases
    update_notice
    [ -n "$dir" ] && [ -d "$dir" ] || exit 0
    target "$dir"
    n=$(repos | while IFS= read -r r; do [ -d "$r/projects/$name" ] && echo "$r"; done | wc -l)
    if [ "$n" -gt 1 ]; then
      echo "WARNING: the project $name is in more than one memory repository. This session"
      echo "uses \"$(repo_alias "$repo")\". Tell the user (sync.sh repos)."
      echo
    fi
    if [ -L "$mem" ] && [ ! -e "$mem" ]; then
      dangling
    elif [ -d "$udir" ]; then
      link "$mem" "$udir"
      local_context "$mem" "$udir"
    fi
    team_context "$name" "$repo"
    ;;
  push)
    repos | while IFS= read -r r; do
      (cd "$r" && push)
    done
    ;;
  check-team)
    input=$(cat)
    file=$(json_field "$input" '.tool_input.file_path' 'd.get("tool_input",{}).get("file_path","")') || exit 0
    rel=""
    base_repo=""
    for r in $(repos); do
      for base in "$r" "$(abs_dir "$r")"; do
        case $file in "$base"/*) rel=${file#"$base"/}; base_repo=$r ;; esac
      done
    done
    [ -n "$rel" ] && is_team_path "$rel" || exit 0
    cd "$base_repo" || exit 0
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
    shift
    d=.
    want=""
    while [ $# -gt 0 ]; do
      case $1 in
        --repo) want=$2; shift 2 ;;
        *) d=$1; shift ;;
      esac
    done
    target "$d"
    if [ -n "$want" ]; then
      wpath=$(alias_path "$want")
      if [ -z "$wpath" ]; then
        echo "sync.sh: no memory repository \"$want\". Add it with: sync.sh add-repo $want <url>" >&2
        exit 1
      fi
      if [ -d "$pdir" ] && [ "$repo" != "$wpath" ]; then
        echo "sync.sh: the project $name is in the memory repository \"$(repo_alias "$repo")\"." >&2
        echo "To move it, use: sync.sh move $d $want" >&2
        exit 1
      fi
      repo=$wpath
      pdir="$repo/projects/$name"
      udir="$pdir/users/$ME"
    fi
    if [ ! -d "$pdir/team" ]; then
      mkdir -p "$pdir/team"
      printf '# Team memory: %s\n\nRules: skill memory-lifecycle, section "Team memory".\n' \
        "$name" > "$pdir/team/README.md"
    fi
    mkdir -p "$udir"
    if [ -L "$mem" ] && [ "$(readlink "$mem")" != "$udir" ]; then
      rm "$mem"
    fi
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
    (cd "$repo" && push "Enable memory of $name for $ME")
    echo "Enabled: $name for $ME, in the memory repository \"$(repo_alias "$repo")\""
    echo "  $mem -> $udir"
    ;;
  disable)
    target "$2"
    if [ ! -d "$udir" ]; then
      echo "Not enabled: $name for $ME"
      exit 0
    fi
    cd "$repo" || exit 1
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
  add-repo)
    a=$2
    u=$3
    if [ -z "$a" ] || [ -z "$u" ]; then
      echo "Usage: sync.sh add-repo <alias> <url>" >&2
      exit 2
    fi
    if [ "$a" = main ] || [ "$(safe_name "$a")" != "$a" ]; then
      echo "sync.sh: the alias must be lower case (a-z 0-9 . _ -) and not \"main\"." >&2
      exit 1
    fi
    if [ ! -d "$EXTRA/$a/.git" ]; then
      mkdir -p "$EXTRA"
      if ! git clone -q "$u" "$EXTRA/$a"; then
        echo "sync.sh: cannot clone $u" >&2
        exit 1
      fi
    fi
    mkdir -p "$(dirname "$REPOS_CONF")"
    touch "$REPOS_CONF"
    if ! grep -q "^$a " "$REPOS_CONF"; then
      echo "$a $u" >> "$REPOS_CONF"
    fi
    push "Add memory repository $a for $ME"
    echo "Added: \"$a\" -> $EXTRA/$a"
    echo "  Your other machines clone it at their next session."
    echo "  Enable a project in it: sync.sh enable <dir> --repo $a"
    ;;
  repos)
    repos | while IFS= read -r r; do
      url=$(git -C "$r" remote get-url origin 2>/dev/null)
      echo "$(repo_alias "$r")  $r  ($url)"
      for p in "$r"/projects/*/; do
        [ -d "$p" ] || continue
        users=$(cd "$p" && ls users 2>/dev/null | tr '\n' ' ')
        echo "    $(basename "$p"): ${users:-(no persons)}"
      done
    done
    ;;
  move)
    if [ $# -eq 2 ]; then d=.; to=$2; else d=$2; to=$3; fi
    target "$d"
    tpath=$(alias_path "$to")
    if [ -z "$tpath" ]; then
      echo "sync.sh: no memory repository \"$to\". Add it with: sync.sh add-repo $to <url>" >&2
      exit 1
    fi
    if [ ! -d "$pdir" ]; then
      echo "sync.sh: the project $name is in no memory repository." >&2
      exit 1
    fi
    if [ "$repo" = "$tpath" ]; then
      echo "The project $name is in \"$to\" already."
      exit 0
    fi
    if [ -d "$tpath/projects/$name" ]; then
      echo "sync.sh: \"$to\" has a project $name already. Merge them by hand." >&2
      exit 1
    fi
    from=$repo
    mkdir -p "$tpath/projects"
    cp -R "$pdir" "$tpath/projects/$name"
    (cd "$tpath" && push "Move project $name from $(repo_alias "$from")")
    for m in "$PROJECTS"/*/memory; do
      [ -L "$m" ] || continue
      case $(readlink "$m") in
        "$pdir/users/"*)
          t=$(readlink "$m")
          rm "$m"
          ln -s "$tpath/projects/$name/${t#"$pdir/"}" "$m"
          ;;
      esac
    done
    (
      cd "$from" || exit 1
      git rm -r -q "projects/$name" >/dev/null 2>&1
      rm -rf "projects/$name"
      push "Move project $name to $to"
    )
    echo "Moved: $name from \"$(repo_alias "$from")\" to \"$to\""
    echo "  The team memory and the personal memory of all persons moved."
    echo "  Each person needs a clone of \"$to\" (sync.sh add-repo $to <url>)."
    ;;
  lint)
    shift
    cd "$START" || exit 1
    lint "$@" || exit 1
    ;;
  status)
    target "$2"
    echo "Project:    $name"
    echo "Repository: $(repo_alias "$repo") ($repo)"
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
    repos | while IFS= read -r r; do
      for p in "$r"/projects/*/; do
        [ -d "$p" ] || continue
        users=$(cd "$p" && ls users 2>/dev/null | tr '\n' ' ')
        echo "$(basename "$p") [$(repo_alias "$r")]: ${users:-(no persons)}"
      done
    done
    ;;
  user)
    echo "$ME"
    ;;
  host)
    echo "$HOST"
    ;;
  setup)
    setup || exit 1
    ;;
  update)
    update || exit 1
    ;;
  version)
    echo "Repository:      v$(repo_version)"
    echo "Latest release:  $(latest_tag) (from the remote \"upstream\", fetched by pull and update)"
    echo "Machine setup:   $(cat "$SETUP_FILE" 2>/dev/null || echo 0) (needed: $SETUP_VERSION)"
    ;;
  *)
    sed -n '2,40s/^# \{0,1\}//p' "$0" >&2
    exit 2
    ;;
esac
exit 0
