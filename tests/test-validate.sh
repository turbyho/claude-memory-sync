#!/bin/sh
# Test: tools/validate.sh finds the problems of a memory repository.
. "$(dirname "$0")/lib.sh"

template "$T/mem.git"
machine a "$T/mem.git" alice@example.com
project a app git@example.com:corp/app.git
run a enable "$T/a/src/app" >/dev/null
R=$T/a/.claude/claude-memory
U=$R/projects/app/users/alice
V="$SRC/tools/validate.sh"

printf -- '---\nname: pnpm\ndescription: the project uses pnpm\nmetadata:\n  status: confirmed\n  role: personal\n---\nx\n' > "$U/pnpm.md"
awk '{ print } $0 == "## Confirmed" { print ""; print "- [pnpm](pnpm.md) - the project uses pnpm" }' "$U/MEMORY.md" > "$T/m" && mv "$T/m" "$U/MEMORY.md"
out=$(sh "$V" "$R" 2>&1)
check "a correct repository passes" contains "$out" "OK: 1 records, no problems."

printf -- '---\nname: orphan\ndescription: no index line\nmetadata:\n  status: tentative\n  role: personal\n---\nx\n' > "$U/orphan.md"
out=$(sh "$V" "$R" 2>&1)
check "a record without an index line fails" contains "$out" "NO INDEX LINE: projects/app/users/alice/orphan.md"
rm "$U/orphan.md"

echo "- [Gone](gone.md) - a missing file" >> "$U/MEMORY.md"
out=$(sh "$V" "$R" 2>&1)
check "a link to a missing file fails" contains "$out" "BROKEN LINK"
sed '/gone\.md/d' "$U/MEMORY.md" > "$T/m" && mv "$T/m" "$U/MEMORY.md"

printf 'no frontmatter\n' > "$U/plain.md"
echo "- [Plain](plain.md) - plain" >> "$U/MEMORY.md"
out=$(sh "$V" "$R" 2>&1)
check "a record without frontmatter fails" contains "$out" "NO FRONTMATTER: projects/app/users/alice/plain.md"
printf -- '---\nname: plain\ndescription: plain\nmetadata:\n  type: project\n---\nx\n' > "$U/plain.md"
out=$(sh "$V" "$R" 2>&1)
check "a record without status and role fails" contains "$out" "NO STATUS OR ROLE"
rm "$U/plain.md"
sed '/plain\.md/d' "$U/MEMORY.md" > "$T/m" && mv "$T/m" "$U/MEMORY.md"

printf -- '---\nname: node\ndescription: node path\nmetadata:\n  status: tentative\n---\nIn /home/alice/.local/node\n' > "$R/projects/app/team/node.md"
out=$(sh "$V" "$R" 2>&1)
code=$?
check "a team record with a forbidden pattern fails" contains "$out" "FORBIDDEN: projects/app/team/node.md"
check "validate exits with 1 at a problem" [ "$code" = 1 ]
rm "$R/projects/app/team/node.md"

out=$(sh "$V" "$R" 2>&1)
check "the repository passes again" contains "$out" "OK: 1 records, no problems."

finish
