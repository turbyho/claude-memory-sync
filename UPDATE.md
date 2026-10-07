# Update of claude-memory-sync: instructions for Claude

This file is for Claude Code. It gives the procedure to update the tool
claude-memory-sync in a memory repository (`~/.claude/claude-memory`).

The tool (`sync.sh`, `CLAUDE-MEMORY.md`, the skill `memory-lifecycle`, the templates) is
in the memory repository. The remote `upstream` is the repository of the tool. A release
is a git tag `vX.Y.Z` in `upstream`.

## When to do the update

- The SessionStart hook shows `UPDATE: claude-memory-sync vX.Y.Z is available`. The
  notice gives the command that shows this file in the new version. Always use the
  instructions of the new version.
- The SessionStart hook shows `SETUP: the setup of this machine has version ...`. Do only
  the section "Setup of a machine".
- The user asks for an update of claude-memory-sync.

## Procedure

1. Tell the user in one sentence: the version now, the new version, and that you do the
   update.
2. Run:

   ```sh
   ~/.claude/claude-memory/sync.sh update
   ```

   The command does these steps, and stops at the first error:
   1. Commits and pushes the local memory changes.
   2. Pulls the memory repository.
   3. Gets the release tags from `upstream`.
   4. Shows the new lines of `CHANGELOG.md`.
   5. Merges the latest release tag. At a conflict, it stops and changes nothing.
   6. Pushes the merge.
   7. Runs `sync.sh setup` (section "Setup of a machine").
3. If the command shows `CONFLICT`, use the section "Conflicts".
4. If the command cannot get the releases (network), tell the user, and stop. The next
   session tries again.
5. Do the steps of the section "Steps for each release", for each release after the old
   version, up to the new version.
6. Report to the user:
   - The old and the new version
   - The changes, from the output of `CHANGELOG.md`, in the language of the user
   - The output of the setup
   - That a new Claude Code session is necessary. Claude Code loads the hooks,
     `CLAUDE-MEMORY.md` and the skill only at the start of a session.

The other machines and persons that use the memory repository get the new version with
their next `sync.sh pull`. Do not tell them to do the update again. If a release changes
the setup, their SessionStart hook shows `SETUP`.

## Setup of a machine

Run:

```sh
~/.claude/claude-memory/sync.sh setup
```

The command does these steps. Each step changes nothing if it is done already:

1. Adds the missing hooks to `~/.claude/settings.json`. It makes a backup first, and keeps
   all other keys and hooks.
2. Adds the import line of `CLAUDE-MEMORY.md` to `~/.claude/CLAUDE.md`.
3. Makes the symlink `~/.claude/skills/memory-lifecycle`.
4. Writes the setup version to `~/.claude/claude-memory-setup`.

Report the output to the user. If a step shows that it did not change a file because the
file is in a different state, tell the user. Do not change that file yourself.

## Conflicts

A conflict occurs when the memory repository has a change in a file of the tool (for
example, the user changed the skill), and the release changes the same lines.

1. Tell the user the files with a conflict. `sync.sh update` stopped and changed
   nothing.
2. Show the user the two changes:

   ```sh
   git -C ~/.claude/claude-memory diff vOLD vNEW -- <file>      # change of the release
   git -C ~/.claude/claude-memory diff vOLD HEAD -- <file>      # change of the user
   ```

   `vOLD` is the version in `VERSION` before the update.
3. Ask the user how to merge: keep the release, keep the change of the user, or combine
   the two.
4. After the approval, do the merge by hand:

   ```sh
   cd ~/.claude/claude-memory
   git merge vNEW
   # edit the files with a conflict
   git add <file>
   git commit --no-edit
   git push
   ./sync.sh setup
   ```

5. Continue with step 5 of the section "Procedure".

## Rules

- Get releases only from the remote `upstream`. Do not change the URL of a remote.
- Do not merge a branch of `upstream`, only a release tag.
- Do not change the memory records during the update.
- If a step fails and you do not know the cause, stop and tell the user.

## Steps for each release

Each release can add steps here. Do the steps of each release after the old version, in
the sequence of the versions.

### v0.3.4

No more steps.

### v0.3.3

No more steps.

### v0.3.2

Do this step only if `tools/migrate.sh` of an older release migrated the memory. Signs:
the records have the history line `<date> <user>@<host> migrated`, and the line
`Last review:` of `MEMORY.md` has the same date. Then nobody did a review: the date is
the date of the migration.

1. Tell the user: the review date is the date of the migration, and N records are
   tentative.
2. Ask the user if you can set `Last review: never` in these `MEMORY.md` files. Then you
   offer a review of the tentative records in each project.
3. After the approval, change the line in each applicable `MEMORY.md`. The Stop hook
   commits and pushes the change.

### v0.3.1

The `MEMORY.md` files from before v0.3.1 have the date of the last review and the rules
in HTML comments. Claude Code removes HTML comments, thus Claude does not see them. Make
them visible in each memory repository (`sync.sh repos` shows them):

```sh
~/.claude/claude-memory/tools/visible-notes.sh ~/.claude/claude-memory
~/.claude/claude-memory/tools/visible-notes.sh ~/.claude/claude-memory.d/<alias>
```

The script changes only your files and the files of other persons in the repository that
have the old comments. The Stop hook commits and pushes the changes. Tell the user how
many files changed in each repository.

### v0.3.0

The `sync.sh` before v0.3.0 updates only the main repository. Thus run the update one
more time. The new `sync.sh` then puts the tool into each project repository:

```sh
~/.claude/claude-memory/sync.sh update
```

The output shows each project repository under "Other memory repositories". Tell the
user which repositories got the tool, and which did not change (no write access). Then
tell the user that each memory repository can now be the main repository of a person
(README.md, section 4.7).

### v0.2.1

No more steps. After the update, you can run `~/.claude/claude-memory/tools/validate.sh`
for each memory repository (`sync.sh repos` shows them), and tell the user the result.

### v0.2.0

No more steps. After the update, tell the user that projects can now use different
memory repositories (README.md, section 4.7), and give the commands `sync.sh add-repo`,
`sync.sh move` and `sync.sh repos`.

### v0.1.0

First release.

A memory repository from before v0.1.0 has no file `VERSION`, and its `sync.sh` has no
command `update`. Do the first update by hand:

```sh
cd ~/.claude/claude-memory
git fetch --tags upstream
git merge v0.1.0
git push
./sync.sh setup
```

If `git merge` shows a conflict, use the section "Conflicts".
