#!/bin/sh
# Test: more memory repositories (main and "x"). alice has two machines (a1, a2), bob
# one machine (b1).
. "$(dirname "$0")/lib.sh"

template "$T/main.git"
git init -q --bare -b main "$T/x.git"
git clone -q "$T/x.git" "$T/xw" 2>/dev/null
echo x > "$T/xw/README.md"
git -C "$T/xw" add -A
git -C "$T/xw" commit -q -m init
git -C "$T/xw" push -q origin main

machine a1 "$T/main.git" alice@example.com
machine a2 "$T/main.git" alice@example.com
machine b1 "$T/main.git" bob@example.com
for m in a1 a2 b1; do
  project $m app git@example.com:corp/app.git
  project $m app2 git@example.com:corp/app2.git
done
X1=$T/a1/.claude/claude-memory.d/x

run a1 enable "$T/a1/src/app" >/dev/null
echo "fact-a" > "$(slug a1 app)/fact-a.md"
run a1 push
run b1 enable "$T/b1/src/app" >/dev/null

out=$(run a1 add-repo x "$T/x.git")
check "add-repo clones the repository" [ -d "$X1/.git" ]
check "add-repo writes repos.conf" grep -q "^x $T/x.git$" "$T/a1/.claude/claude-memory/users/alice/repos.conf"
out=$(hook a2 app)
check "the other machine clones the repository at the first pull" [ -d "$T/a2/.claude/claude-memory.d/x/.git" ]
check "the clone is told to Claude" contains "$out" "NOTICE: cloned the memory repository \"x\""

run a1 enable "$T/a1/src/app2" --repo x >/dev/null
check "enable --repo puts the project into x" [ -d "$X1/projects/app2/users/alice" ]
hook a2 app2 >/dev/null
check "the other machine links app2 into x" [ "$(readlink "$(slug a2 app2)")" = "$T/a2/.claude/claude-memory.d/x/projects/app2/users/alice" ]

run a1 move "$T/a1/src/app" x >/dev/null
check "move removes the project from main" [ ! -d "$T/a1/.claude/claude-memory/projects/app" ]
check "move copies the personal memory of all persons" [ -d "$X1/projects/app/users/bob" ]
check "move relinks this machine" [ "$(readlink "$(slug a1 app)")" = "$X1/projects/app/users/alice" ]

out=$(hook a2 app)
check "the other machine relinks the moved project" [ "$(readlink "$(slug a2 app)")" = "$T/a2/.claude/claude-memory.d/x/projects/app/users/alice" ]
check "the relink is told to Claude" contains "$out" "is now in the memory repository \"x\""
check "the memory is complete after the move" [ -f "$(slug a2 app)/fact-a.md" ]

out=$(hook b1 app)
check "a machine without the clone gets a local copy" sh -c '[ -d "$1" ] && [ ! -L "$1" ]' x "$(slug b1 app)"
check "a machine without the clone gets a warning" contains "$out" "Move project app to x"
run b1 add-repo x "$T/x.git" >/dev/null
hook b1 app >/dev/null
check "after add-repo the project links into x" [ "$(readlink "$(slug b1 app)")" = "$T/b1/.claude/claude-memory.d/x/projects/app/users/bob" ]
check "the local copy merged without a host file" sh -c '! ls "$1" | grep -q "\.b1\.md$"' x "$T/b1/.claude/claude-memory.d/x/projects/app/users/bob"

check "status shows the repository" contains "$(run a1 status "$T/a1/src/app")" "Repository: x"
check "list shows the repository" contains "$(run a1 list)" "app [x]: alice bob"

w() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"; }
code=$(w "$X1/projects/app/team/t.md" "in /home/alice/x" | HOME=$T/a1 "$T/a1/.claude/claude-memory/sync.sh" check-team >/dev/null 2>&1; echo $?)
check "check-team checks the team memory in x" [ "$code" = 2 ]

echo "fact-b" > "$(slug a1 app)/fact-b.md"
run a1 push
check "push sends the changes of x" contains "$(git -C "$T/x.git" log --name-only --format= -1)" "fact-b.md"

out=$(run a1 enable "$T/a1/src/app" --repo main 2>&1)
check "enable --repo refuses a project of a different repository" contains "$out" "sync.sh move"

# Rename: the git server renames x.git to y.git; alice renames the alias x to y.
mv "$T/x.git" "$T/y.git"
out=$(run a1 rename-repo x y "$T/y.git")
Y1=$T/a1/.claude/claude-memory.d/y
check "rename-repo renames the clone" sh -c '[ -d "$1/.git" ] && [ ! -e "$2" ]' x "$Y1" "$X1"
check "rename-repo sets the new URL" [ "$(git -C "$Y1" remote get-url origin)" = "$T/y.git" ]
check "rename-repo relinks the projects" [ "$(readlink "$(slug a1 app)")" = "$Y1/projects/app/users/alice" ]
check "rename-repo changes repos.conf" grep -q -x "y $T/y.git" "$T/a1/.claude/claude-memory/users/alice/repos.conf"
check "rename-repo removes the old line" sh -c '! grep -q "^x " "$1"' x "$T/a1/.claude/claude-memory/users/alice/repos.conf"
check "rename-repo writes repos.renamed" grep -q -x "x y" "$T/a1/.claude/claude-memory/users/alice/repos.renamed"

# The other machine of alice renames its clone at the next session.
out=$(hook a2 app)
Y2=$T/a2/.claude/claude-memory.d/y
check "the other machine renames its clone" sh -c '[ -d "$1/.git" ] && [ ! -e "$2" ]' x "$Y2" "$T/a2/.claude/claude-memory.d/x"
check "the rename is told to Claude" contains "$out" "renamed the memory repository \"x\" to \"y\""
check "the other machine relinks the projects" [ "$(readlink "$(slug a2 app)")" = "$Y2/projects/app/users/alice" ]
check "the other machine sets the new URL" [ "$(git -C "$Y2" remote get-url origin)" = "$T/y.git" ]
check "no warning about a project in two repositories" sh -c '! printf "%s" "$1" | grep -q "more than one memory repository"' x "$out"
echo "fact-c" > "$(slug a2 app)/fact-c.md"
run a2 push
check "push after the rename goes to the new URL" contains "$(git -C "$T/y.git" log --name-only --format= -1)" "fact-c.md"

# bob has his own list of repositories: he renames too.
out=$(run b1 rename-repo x team "$T/y.git")
check "an other person can use a different alias" [ "$(readlink "$(slug b1 app)")" = "$T/b1/.claude/claude-memory.d/team/projects/app/users/bob" ]

# A wrong URL changes nothing.
out=$(run a1 rename-repo y z "$T/none.git" 2>&1)
check "rename-repo with an unreachable URL changes nothing" sh -c '[ -d "$1" ] && printf "%s" "$2" | grep -q "Nothing changed"' x "$Y1" "$out"

finish
