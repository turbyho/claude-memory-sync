#!/bin/sh
# Test: roles of the memory, linking, team memory check, disable, slug.
# alice has two machines (a1, a2), bob one machine (b1).
. "$(dirname "$0")/lib.sh"

template "$T/mem.git"
machine a1 "$T/mem.git" alice@example.com
machine a2 "$T/mem.git" alice@example.com
machine b1 "$T/mem.git" bob@example.com
for m in a1 a2 b1; do project $m app git@example.com:corp/example-app.git; done

check "user name comes from user.email" [ "$(run a1 user)" = alice ]
check "host name comes from CLAUDE_MEMORY_HOST" [ "$(run a1 host)" = a1 ]

# Enable adopts a local memory directory, with a subdirectory.
M1=$(slug a1 app)
mkdir -p "$M1/invalid"
echo "old" > "$M1/old.md"
echo "- [Old](old.md) - old" > "$M1/MEMORY.md"
echo "x" > "$M1/invalid/INDEX.md"
run a1 enable "$T/a1/src/app" >/dev/null
U1=$T/a1/.claude/claude-memory/projects/example-app/users/alice
check "enable adopts the local files" [ -f "$U1/old.md" ]
check "enable merges a subdirectory" [ -f "$U1/invalid/INDEX.md" ]
check "enable does not copy a subdirectory as a file" [ ! -e "$U1/invalid.a1.md" ]
check "enable makes the symlink" [ "$(readlink "$M1")" = "$U1" ]
check "enable makes the team directory" [ -f "$T/a1/.claude/claude-memory/projects/example-app/team/README.md" ]

# The second machine of alice links the same personal memory.
out=$(hook a2 app)
check "a2 links the memory of alice" [ "$(readlink "$(slug a2 app)")" = "$T/a2/.claude/claude-memory/projects/example-app/users/alice" ]
check "a2 gets the local memory context" contains "$out" "Local memory of this machine (a2)"

# bob did not enable the project: no link, but the team memory is visible.
out=$(hook b1 app)
check "b1 is not linked" [ ! -e "$(slug b1 app)" ]
check "b1 sees the team memory" contains "$out" "Team memory of this project"

# Team records, a forbidden pattern, local memory.
TD=$T/a1/.claude/claude-memory/projects/example-app/team
printf -- '---\nname: pnpm\ndescription: The project uses pnpm\nmetadata:\n  status: confirmed\n---\nx\n' > "$TD/pnpm.md"
printf -- '---\nname: node\ndescription: node path\n---\nIn /home/alice/.local/node\n' > "$TD/node.md"
mkdir -p "$M1/hosts/a1"
printf '# Local\n\n## Confirmed\n- [Database](database.md) - local database on port 5433\n' > "$M1/hosts/a1/INDEX.md"
run a1 push
committed=$(git -C "$T/mem.git" log --name-only --format= -1)
check "a good team record is committed" contains "$committed" "team/pnpm.md"
check "a team record with a forbidden pattern is not committed" sh -c "! printf '%s' \"\$1\" | grep -q team/node.md" x "$committed"
out=$(hook a1 app)
check "pull warns about the team file" contains "$out" "team/node.md:5"
check "pull gives the local index" contains "$out" "local database on port 5433"
check "pull gives the team index" contains "$out" "[pnpm](pnpm.md) - The project uses pnpm"

run b1 enable "$T/b1/src/app" >/dev/null
check "list shows the two persons" contains "$(run b1 list)" "example-app [main]: alice bob"

# check-team (PreToolUse hook).
w() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"; }
B=$T/b1/.claude/claude-memory
hook_code() { w "$1" "$2" | HOME=$T/b1 "$3" check-team >/dev/null 2>&1; echo $?; }
check "check-team blocks a home path" [ "$(hook_code "$B/projects/example-app/team/x.md" "in /Users/bob/x" "$B/sync.sh")" = 2 ]
check "check-team passes a relative path" [ "$(hook_code "$B/projects/example-app/team/x.md" "src/main.c:42" "$B/sync.sh")" = 0 ]
check "check-team ignores the personal memory" [ "$(hook_code "$B/projects/example-app/users/bob/x.md" "in /Users/bob/x" "$B/sync.sh")" = 0 ]
check "check-team checks a team shared topic" [ "$(hook_code "$B/shared/db/x.md" "file:///etc" "$B/sync.sh")" = 2 ]
sed 's/command -v jq/false/' "$B/sync.sh" > "$B/nojq.sh"
chmod +x "$B/nojq.sh"
check "check-team without jq blocks" [ "$(hook_code "$B/projects/example-app/team/x.md" "data in ~/secret" "$B/nojq.sh")" = 2 ]
check "check-team without jq passes" [ "$(hook_code "$B/projects/example-app/team/x.md" "plain fact" "$B/nojq.sh")" = 0 ]
rm "$B/nojq.sh"

# Disable: the other machine of alice gets a local copy, bob does not change.
run a1 disable "$T/a1/src/app" >/dev/null
hook a2 app >/dev/null
check "a2 has a local copy after disable" sh -c '[ -d "$1" ] && [ ! -L "$1" ] && [ -f "$1/MEMORY.md" ]' x "$(slug a2 app)"
check "the memory of bob stays" [ -d "$T/b1/.claude/claude-memory/projects/example-app/users/bob" ]

# Slug: a subdirectory and a worktree use the memory of the main working tree. A path
# with "ch" keeps it, also in a Czech locale.
project a1 chapp git@example.com:corp/chapp.git
mkdir -p "$T/a1/src/chapp/sub"
echo x > "$T/a1/src/chapp/sub/f"
git -C "$T/a1/src/chapp" add -A
git -C "$T/a1/src/chapp" commit -q -m x
git -C "$T/a1/src/chapp" worktree add -q "$T/a1/src/chapp-wt" -b wt
LANG=cs_CZ.UTF-8 run a1 enable "$T/a1/src/chapp/sub" >/dev/null
printf '{"cwd":"%s"}' "$T/a1/src/chapp-wt" | HOME=$T/a1 LANG=cs_CZ.UTF-8 "$T/a1/.claude/claude-memory/sync.sh" pull >/dev/null
check "subdirectory uses the slug of the main working tree" [ -L "$(slug a1 chapp)" ]
check "worktree makes no other memory directory" [ ! -e "$(slug a1 chapp-wt)" ]

# The default directory and a relative path are from the directory of the user, not
# from the repository.
out=$(cd "$T/a1/src/chapp" && HOME=$T/a1 CLAUDE_MEMORY_HOST=a1 "$T/a1/.claude/claude-memory/sync.sh" status)
check "status without a directory shows the project of the current directory" contains "$out" "Project:    chapp"
project a1 rel git@example.com:corp/rel.git
(cd "$T/a1/src" && HOME=$T/a1 CLAUDE_MEMORY_HOST=a1 "$T/a1/.claude/claude-memory/sync.sh" enable rel >/dev/null)
check "enable with a relative path enables that project" [ -d "$T/a1/.claude/claude-memory/projects/rel/users/alice" ]
check "enable with a relative path does not enable the repository" [ ! -d "$T/a1/.claude/claude-memory/projects/claude-memory" ]

# The index has visible notes: Claude Code removes HTML comments from MEMORY.md.
idx=$T/a1/.claude/claude-memory/projects/rel/users/alice/MEMORY.md
check "a new index has a visible review line" grep -q -x 'Last review: never' "$idx"
check "a new index has no HTML comment" sh -c '! grep -q "<!--" "$1"' x "$idx"

finish
