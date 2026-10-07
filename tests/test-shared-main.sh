#!/bin/sh
# Test: a memory repository is the main repository of one person and a project
# repository of an other person. alice: main "a.git", project repository "x" (team).
# bob: main "x". Each memory repository gets the tool, and an update reaches all copies.
. "$(dirname "$0")/lib.sh"

# Tool repository (upstream) with the release v1.0.0.
template "$T/up.git"
git clone -q "$T/up.git" "$T/upw"
echo 1.0.0 > "$T/upw/VERSION"
git -C "$T/upw" commit -q -am "v1.0.0"
git -C "$T/upw" tag v1.0.0
git -C "$T/upw" push -q origin main v1.0.0

# alice: main repository from v1.0.0, with the remote upstream and its tags.
git init -q --bare -b main "$T/a.git"
git clone -q "$T/up.git" "$T/seed"
git -C "$T/seed" reset -q --hard v1.0.0
git -C "$T/seed" push -q "$T/a.git" main
machine a "$T/a.git" alice@example.com
git -C "$T/a/.claude/claude-memory" remote add upstream "$T/up.git"
git -C "$T/a/.claude/claude-memory" fetch -q --tags upstream
project a app git@example.com:corp/app.git

# The team repository "x" is empty.
git init -q --bare -b main "$T/x.git"
out=$(run a add-repo x "$T/x.git")
check "add-repo puts the tool into an empty repository" contains "$out" "\"x\": tool v1.0.0"
check "the tool is pushed to the team repository" [ "$(git -C "$T/x.git" show main:VERSION)" = 1.0.0 ]
run a enable "$T/a/src/app" --repo x >/dev/null
check "the project is in x" git -C "$T/x.git" cat-file -e main:projects/app/users/alice/MEMORY.md

# bob uses x as his main repository.
machine b "$T/x.git" bob@example.com
git -C "$T/b/.claude/claude-memory" remote add upstream "$T/up.git"
project b app git@example.com:corp/app.git
check "bob has the tool in his main repository" [ -x "$T/b/.claude/claude-memory/sync.sh" ]
out=$(run b setup)
check "setup operates from a team repository" contains "$out" "Setup version"
run b enable "$T/b/src/app" >/dev/null
check "bob enables the project in his main repository" [ "$(readlink "$(slug b app)")" = "$T/b/.claude/claude-memory/projects/app/users/bob" ]
hook a app >/dev/null
check "alice sees bob in the team repository" contains "$(run a list)" "app [x]: alice bob"

# A new release: the update of alice reaches her main repository and x.
echo 1.1.0 > "$T/upw/VERSION"
printf '\n## v1.1.0 - test\n\n- Feature Y\n' >> "$T/upw/CHANGELOG.md"
git -C "$T/upw" commit -q -am "v1.1.0"
git -C "$T/upw" tag v1.1.0
git -C "$T/upw" push -q origin main v1.1.0
out=$(run a update)
check "update merges the release into the main repository" [ "$(cat "$T/a/.claude/claude-memory/VERSION")" = 1.1.0 ]
check "update puts the release into x" contains "$out" "\"x\": tool v1.1.0"
check "x on the server has the new tool" [ "$(git -C "$T/x.git" show main:VERSION)" = 1.1.0 ]
check "the data of x stays" git -C "$T/x.git" cat-file -e main:projects/app/users/bob/MEMORY.md
rm -f "$T/b/.claude/claude-memory/.git/claude-memory-sync-fetch"
out=$(hook b app)
check "bob gets the new tool with pull" [ "$(cat "$T/b/.claude/claude-memory/VERSION")" = 1.1.0 ]
check "bob gets no UPDATE notice" sh -c '! printf "%s" "$1" | grep -q "^UPDATE:"' x "$out"
check "version shows the tool of x" contains "$(run a version)" "Tool in \"x\": v1.1.0"

# A repository with its own README.md (made by the git server) gets the tool, and keeps
# its README.md.
git init -q --bare -b main "$T/rd.git"
git clone -q "$T/rd.git" "$T/rdw" 2>/dev/null
echo "Team memory" > "$T/rdw/README.md"
git -C "$T/rdw" add -A
git -C "$T/rdw" commit -q -m init
git -C "$T/rdw" push -q origin main
out=$(run a add-repo rd "$T/rd.git")
check "a repository with a README gets the tool" contains "$out" "\"rd\": tool v1.1.0"
check "the repository keeps its README" [ "$(git -C "$T/rd.git" show main:README.md)" = "Team memory" ]
check "the repository has sync.sh" git -C "$T/rd.git" cat-file -e main:sync.sh

# A repository without write access does not change.
git init -q --bare -b main "$T/ro.git"
git clone -q "$T/ro.git" "$T/row" 2>/dev/null
echo data > "$T/row/data.txt"
git -C "$T/row" add -A
git -C "$T/row" commit -q -m data
git -C "$T/row" push -q origin main
chmod -R a-w "$T/ro.git"
out=$(run a add-repo ro "$T/ro.git")
check "add-repo tells that it cannot push the tool" contains "$out" "cannot push"
check "the local clone without write access does not change" [ ! -f "$T/a/.claude/claude-memory.d/ro/sync.sh" ]
check "add-repo still adds the repository" grep -q "^ro " "$T/a/.claude/claude-memory/users/alice/repos.conf"
chmod -R u+w "$T/ro.git"

finish
