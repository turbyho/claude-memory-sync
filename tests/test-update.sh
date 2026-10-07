#!/bin/sh
# Test: setup, update notice, update, conflict at an update.
. "$(dirname "$0")/lib.sh"

# The tool repository (upstream) with the release v1.0.0, and a memory repository made
# from it. The test sets its own versions, thus it does not depend on VERSION of SRC.
template "$T/up.git"
git clone -q "$T/up.git" "$T/upw"
echo 1.0.0 > "$T/upw/VERSION"
git -C "$T/upw" commit -q -am "v1.0.0"
git -C "$T/upw" tag v1.0.0
git -C "$T/upw" push -q origin main v1.0.0
git init -q --bare -b main "$T/mem.git"
git clone -q "$T/up.git" "$T/seed"
git -C "$T/seed" reset -q --hard v1.0.0
git -C "$T/seed" push -q "$T/mem.git" main

machine a "$T/mem.git" alice@example.com
git -C "$T/a/.claude/claude-memory" remote add upstream "$T/up.git"
A=$T/a
printf '{"permissions":{"allow":["x"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"other"}]}]}}\n' > "$A/.claude/settings.json"
printf '# my rules\n' > "$A/.claude/CLAUDE.md"

out=$(printf '{"cwd":"/nonexistent"}' | HOME=$A "$A/.claude/claude-memory/sync.sh" pull)
check "pull shows SETUP before the setup" contains "$out" "SETUP: the setup of this machine has version 0"
check "pull shows no UPDATE at the latest release" sh -c '! printf "%s" "$1" | grep -q "^UPDATE:"' x "$out"

out=$(run a setup)
check "setup adds the three hooks" contains "$out" "Hooks added: pull push check-team"
check "setup keeps the other hooks" grep -q '"other"' "$A/.claude/settings.json"
check "setup keeps the other keys" grep -q '"allow"' "$A/.claude/settings.json"
check "setup adds the import line" grep -q -x '@~/.claude/claude-memory/CLAUDE-MEMORY.md' "$A/.claude/CLAUDE.md"
check "setup keeps CLAUDE.md" grep -q '# my rules' "$A/.claude/CLAUDE.md"
check "setup makes the skill symlink" [ -L "$A/.claude/skills/memory-lifecycle" ]
out=$(run a setup)
check "setup is idempotent" contains "$out" "Hooks: present"
check "setup adds each hook one time" [ "$(grep -c 'sync.sh pull' "$A/.claude/settings.json")" = 1 ]

# setup with python3, not jq.
machine p "$T/mem.git" alice@example.com
P=$T/p/.claude/claude-memory
sed 's/command -v jq/false/' "$P/sync.sh" > "$P/nojq.sh"
chmod +x "$P/nojq.sh"
out=$(HOME=$T/p "$P/nojq.sh" setup)
check "setup without jq adds the hooks" contains "$out" "Hooks added: pull push check-team"
check "setup without jq writes valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$T/p/.claude/settings.json"

# A new release with a new setup version.
echo 1.1.0 > "$T/upw/VERSION"
sed 's/^SETUP_VERSION=[0-9]*$/SETUP_VERSION=99/' "$T/upw/sync.sh" > "$T/upw/sync.sh.new"
mv "$T/upw/sync.sh.new" "$T/upw/sync.sh"
chmod +x "$T/upw/sync.sh"
printf '\n## v1.1.0 - test\n\n- New feature X\n' >> "$T/upw/CHANGELOG.md"
git -C "$T/upw" commit -q -am "v1.1.0"
git -C "$T/upw" tag v1.1.0
git -C "$T/upw" push -q origin main v1.1.0

rm -f "$A/.claude/claude-memory/.git/claude-memory-sync-fetch"
out=$(printf '{"cwd":"/nonexistent"}' | HOME=$A "$A/.claude/claude-memory/sync.sh" pull)
check "pull shows UPDATE" contains "$out" "UPDATE: claude-memory-sync v1.1.0 is available. This repository has v1.0.0."
check "UPDATE links to UPDATE.md of the new release" contains "$out" "show v1.1.0:UPDATE.md"

out=$(run a update)
check "update shows the changes" contains "$out" "New feature X"
check "update merges the release" [ "$(cat "$A/.claude/claude-memory/VERSION")" = 1.1.0 ]
check "update pushes" [ "$(git -C "$T/mem.git" show main:VERSION)" = 1.1.0 ]
check "update runs the new setup" [ "$(cat "$A/.claude/claude-memory-setup")" = 99 ]

machine b "$T/mem.git" alice@example.com
out=$(printf '{"cwd":"/nonexistent"}' | HOME=$T/b "$T/b/.claude/claude-memory/sync.sh" pull)
check "an other machine gets the release with pull" [ "$(cat "$T/b/.claude/claude-memory/VERSION")" = 1.1.0 ]
check "an other machine shows SETUP" contains "$out" "needs
version 99"

# Conflict: the memory repository changed the skill, the release changes the same line.
S=skills/memory-lifecycle/SKILL.md
sed 's/^# Memory lifecycle$/# Memory lifecycle (my version)/' "$A/.claude/claude-memory/$S" > "$T/x" && mv "$T/x" "$A/.claude/claude-memory/$S"
git -C "$A/.claude/claude-memory" commit -q -am "my skill"
sed 's/^# Memory lifecycle$/# Memory lifecycle v3/' "$T/upw/$S" > "$T/x" && mv "$T/x" "$T/upw/$S"
echo 1.2.0 > "$T/upw/VERSION"
git -C "$T/upw" commit -q -am "v1.2.0"
git -C "$T/upw" tag v1.2.0
git -C "$T/upw" push -q origin main v1.2.0
before=$(git -C "$A/.claude/claude-memory" rev-parse HEAD)
out=$(run a update 2>&1)
code=$?
check "update stops at a conflict" [ "$code" -ne 0 ]
check "update names the file with the conflict" contains "$out" "$S"
check "update changes nothing at a conflict" [ "$(git -C "$A/.claude/claude-memory" rev-parse HEAD)" = "$before" ]
check "update leaves no merge in progress" sh -c '[ -z "$(git -C "$1" status --porcelain)" ]' x "$A/.claude/claude-memory"

finish
