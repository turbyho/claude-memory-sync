#!/bin/sh
# Test: tools/migrate.sh, tools/validate.sh and tools/relink.sh with an old layout.
. "$(dirname "$0")/lib.sh"

# Old layout: two projects, a shared directory "infra" with symlinks.
O=$T/old
mkdir -p "$O/projects/app" "$O/projects/web" "$O/infra"
ln -s ../../infra "$O/projects/app/infra"
ln -s ../../infra "$O/projects/web/infra"
cat > "$O/projects/app/MEMORY.md" <<'EOF'
# Memory Index

Format note for this project.

## Build

- [Ninja build](ninja.md) - the build needs ninja
- [Probe](probe.md) - probe on /dev/ttyACM0

## Infra

Shared with web (infra/ = shared dir):
- [Server](infra/server.md) - SSH to the test server
EOF
printf -- '---\nname: ninja\ndescription: the build needs ninja\nmetadata:\n  type: project\n  verified: 2026-01-01\n---\nCMakeLists.txt:12\n' > "$O/projects/app/ninja.md"
printf -- '---\nname: probe\ndescription: probe on /dev/ttyACM0\nmetadata:\n  type: reference\n---\nx\n' > "$O/projects/app/probe.md"
printf -- '---\nname: orphan\ndescription: a record without an index line\nmetadata:\n  type: project\n---\nx\n' > "$O/projects/app/orphan.md"
printf -- '---\nmetadata:\n  type: project\nname: order\ndescription: metadata is not the last key\n---\nx\n' > "$O/projects/web/order.md"
printf 'no frontmatter\n' > "$O/projects/web/plain.md"
cat > "$O/projects/web/MEMORY.md" <<'EOF'
- [Order](order.md) - metadata is not the last key
- [Plain](plain.md) - no frontmatter
- [Server](infra/server.md) - SSH to the test server
EOF
printf -- '---\nname: server\ndescription: SSH to the test server\nmetadata:\n  type: reference\n---\nssh in ~/.ssh/config\n' > "$O/infra/server.md"
echo "app/probe.md" > "$T/local.txt"

# New repository: a copy of the template.
template "$T/new.git"
git clone -q "$T/new.git" "$T/new"

out=$(sh "$SRC/tools/migrate.sh" --old "$O" --new "$T/new" --user alice --host laptop \
  --local "$T/local.txt" --date 2026-01-02 2>&1)
N=$T/new/projects
check "migrate reports the records" contains "$out" "Migrated 6 records of 2 projects."
check "migrate warns about a record without frontmatter" contains "$out" "no frontmatter"
check "migrate makes an index line for a record without one" contains "$out" "orphan.md had no index line"
check "a verified record is confirmed" grep -q '^  status: confirmed' "$N/app/users/alice/ninja.md"
check "a record without verified is tentative" grep -q '^  status: tentative' "$N/app/users/alice/orphan.md"
check "the history line has the user and the host" grep -q -- '- 2026-01-02 alice@laptop migrated' "$N/app/users/alice/ninja.md"
check "the local record goes to hosts/<host>" grep -q '^  role: local' "$N/app/users/alice/hosts/laptop/probe.md"
check "the local index has the record" grep -q '](probe.md)' "$N/app/users/alice/hosts/laptop/INDEX.md"
check "the personal index has no local record" sh -c '! grep -q "](probe.md)" "$1"' x "$N/app/users/alice/MEMORY.md"
check "the topic heading stays" grep -q '^### Build' "$N/app/users/alice/MEMORY.md"
check "the kept text stays" grep -q '^Format note for this project.' "$N/app/users/alice/MEMORY.md"
check "the old note about the shared dir is removed" sh -c '! grep -q "Shared with" "$1"' x "$N/app/users/alice/MEMORY.md"
check "the shared dir becomes a personal shared topic" [ -f "$T/new/users/alice/shared/infra/server.md" ]
check "the topic line is in Groups" grep -q '^- \[infra\](~/.claude/claude-memory/users/alice/shared/infra/) - personal shared topic: Server' "$N/web/users/alice/MEMORY.md"
check "the topic README lists the projects" grep -q '^- projects/app/' "$T/new/users/alice/shared/infra/README.md"
check "metadata that is not the last key gets the fields" sh -c 'awk "/^metadata:/{m=1} m&&/^  status:/{s=1} END{exit !s}" "$1"' x "$N/web/users/alice/order.md"
check "the order record keeps its name" grep -q '^name: order' "$N/web/users/alice/order.md"
check "each project has a team directory" [ -f "$N/web/team/README.md" ]

out=$(sh "$SRC/tools/validate.sh" "$T/new" 2>&1)
check "validate finds the record without frontmatter" contains "$out" "NO FRONTMATTER: projects/web/users/alice/plain.md"
# Fix the record, then the repository must be valid.
printf -- '---\nname: plain\ndescription: no frontmatter\nmetadata:\n  status: tentative\n  role: personal\n---\nno frontmatter\n' > "$N/web/users/alice/plain.md"
out=$(sh "$SRC/tools/validate.sh" "$T/new" 2>&1)
check "validate passes after the fix" contains "$out" "OK: 6 records, no problems."

out=$(sh "$SRC/tools/migrate.sh" --old "$O" --new "$T/new" --user alice --host laptop 2>&1)
check "migrate does not overwrite an existing personal memory" contains "$out" "exists. Stop."

# relink: a symlink to the old repository goes to the new one.
mkdir -p "$T/home/.claude/projects/-src-app"
ln -s "$O/projects/app" "$T/home/.claude/projects/-src-app/memory"
HOME=$T/home sh "$SRC/tools/relink.sh" "$O" "$T/new" alice >/dev/null
check "relink points the symlink to the new personal memory" [ "$(readlink "$T/home/.claude/projects/-src-app/memory")" = "$N/app/users/alice" ]

finish
