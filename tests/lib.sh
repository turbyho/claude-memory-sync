# Helpers for the tests. Each test file sources this file. POSIX sh.
#
# A test runs in a temporary directory. Each machine of a test has its own HOME, thus
# the tests do not touch ~/.claude of the user. The tests need git, and jq or python3.

SRC=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/claude-memory-sync-test.XXXXXX")
trap 'rm -rf "$T"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset CLAUDE_MEMORY_REPO CLAUDE_MEMORY_EXTRA CLAUDE_MEMORY_USER CLAUDE_MEMORY_HOST

PASSES=0
FAILS=0

# check <description> <command>...: the command must succeed.
check() {
  d=$1
  shift
  if "$@" >/dev/null 2>&1; then
    PASSES=$((PASSES + 1))
  else
    FAILS=$((FAILS + 1))
    echo "FAIL: $d"
  fi
}

# contains <text> <part>: the text contains the part.
contains() {
  printf '%s' "$1" | grep -q -F -- "$2"
}

# finish: write the result. Exit status 1 if a check failed.
finish() {
  echo "$(basename "$0"): $PASSES passed, $FAILS failed"
  [ "$FAILS" -eq 0 ]
}

# template <bare repo>: make a bare repository with the working tree of SRC as one commit.
template() {
  git init -q --bare -b main "$1"
  w="$T/tpl.$$.$(basename "$1")"
  git clone -q "$1" "$w" 2>/dev/null
  (cd "$SRC" && tar cf - --exclude=.git --exclude=tests .) | (cd "$w" && tar xf -)
  git -C "$w" add -A
  git -C "$w" commit -q -m template
  git -C "$w" push -q origin main
  rm -rf "$w"
}

# machine <name> <memory repo url> <email>: a machine with its HOME and a clone of the
# memory repository. Sets H to its HOME.
machine() {
  H=$T/$1
  mkdir -p "$H/.claude" "$H/src"
  git clone -q "$2" "$H/.claude/claude-memory"
  git -C "$H/.claude/claude-memory" config user.email "$3"
}

# project <machine> <dir> <remote url>: a git project on a machine.
project() {
  git init -q "$T/$1/src/$2"
  git -C "$T/$1/src/$2" remote add origin "$3"
}

# run <machine> <sync.sh arguments>...
run() {
  m=$1
  shift
  HOME=$T/$m CLAUDE_MEMORY_HOST=$m "$T/$m/.claude/claude-memory/sync.sh" "$@"
}

# hook <machine> <project dir>: the SessionStart hook of a session in the project.
hook() {
  printf '{"cwd":"%s"}' "$T/$1/src/$2" |
    HOME=$T/$1 CLAUDE_MEMORY_HOST=$1 "$T/$1/.claude/claude-memory/sync.sh" pull
}

# slug <machine> <project dir>: the memory directory of the project on the machine.
slug() {
  echo "$T/$1/.claude/projects/$(printf '%s' "$T/$1/src/$2" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')/memory"
}
