## Claude memory: synced repository

The auto memory of some projects is in git repositories. A sync script copies it to all
machines and to all persons that use the repository. The tool is in the main repository
`~/.claude/claude-memory`. Full description: `~/.claude/claude-memory/README.md`. Full
procedure: skill `memory-lifecycle`. Load the skill before you write, review or
invalidate a record.

`<repo>` is the memory repository of the project: the main repository, or a different
repository in `~/.claude/claude-memory.d/<alias>/`. `sync.sh status` shows it. The
SessionStart hook gives the full paths. The main repository is the clone in
`~/.claude/claude-memory` of this person. A repository can be the main repository of one
person and a project repository of an other person. Each memory repository has the tool.

### Roles

| Role | Location | Who uses it |
|---|---|---|
| Team | `<repo>/projects/<name>/team/` | All persons that use the repository |
| Personal | the memory directory of the session (`<repo>/projects/<name>/users/<user>/`) | One person, on all machines of the person |
| Local | `<memory directory>/hosts/<host>/` | One person, on one machine |

- The memory directory of the session is a symlink to `<repo>/projects/<name>/users/<user>/`
  if the personal memory is enabled. If it is a real directory, the personal memory is
  not synced. If the user asks to enable it, run
  `~/.claude/claude-memory/sync.sh enable <project-dir>`. To use a different repository,
  add `--repo <alias>`.
- The SessionStart hook gives you the index of the local memory and of the team memory.
- A line in `## Groups` of `MEMORY.md` can link to a shared topic for more than one
  project: `<repo>/shared/<topic>/` (team) or `<repo>/users/<user>/shared/<topic>/`
  (personal). A shared topic is in the same repository as its projects.
- `<user>` is the output of `~/.claude/claude-memory/sync.sh user`, `<host>` the output
  of `~/.claude/claude-memory/sync.sh host`.
- All persons with access to the repository can read all roles. Do not write private
  information into the memory.

### Select the role of a new record

1. Local: it contains an absolute path, a path in the home directory, a link outside the
   project, a device name, or a setting of this machine.
2. Personal: it is about the user (preference, work method, decision, correction).
3. Ask the user "team memory or personal memory?": it is a fact about the project that
   can be correct for all persons, and the project has a team memory.
4. Personal: all other records.

Then select the place of a team or personal record. If the fact applies to more than one
project, write it into a shared topic of its role (`users/<user>/shared/<topic>/` or
`shared/<topic>/`), not into one project and not as a copy into each project. If no topic
fits, propose a new topic to the user, and make it only after the approval. A local
record always stays in the project.

### Rules for memory writes

1. Each personal record must have a line in `MEMORY.md`, or in the `INDEX.md` of its
   group. Claude Code loads only the first 200 lines or 25 KB of `MEMORY.md` at the
   start of a session, and no record files.
2. Each local record must have a line in `hosts/<host>/INDEX.md`. The team memory has no
   index file: the hook makes the index from the `description` of each record.
3. Before you write a new record, and before you say that the memory has no information
   about a topic, search with Grep in the memory directory, in the team memory, and in
   the invalid records. If an existing record covers the topic, update it. Do not make a
   duplicate.
4. Write, change or invalidate a team record only after the user approved it. A team
   record must not contain absolute paths, home directory paths, links outside the
   project, or machine names. The PreToolUse hook blocks such a write.
5. Never write a credential value (password, token, key) into memory. Write the name of
   the env var or of the file that holds the value.
6. Do not change `sync.sh`, the hooks or the symlinks if the user does not tell you to.
7. Do not move or rename a memory directory. Do not replace the symlink with a real
   directory.

### Memory lifecycle

- Each record has a state: `tentative`, `confirmed` or `invalid`. A new record starts as
  `tentative`. Exception: a preference or a decision that the user explicitly states is
  `confirmed`.
- A `confirmed` record is a fact. A `tentative` record is a hint. Verify it before a risky
  action that depends on it.
- A record in `invalid/` (or `team/invalid/`) is a known false or outdated claim. Never
  use it as a fact. If someone gives an invalid claim again, tell the user.
- When evidence shows that a record is not correct, do not delete it. Move it to
  `invalid/` with the reason.
- The weight of a record comes from its state, not from the position of its line.
- If the line `Last review: <date>` in `MEMORY.md` is older than 14 days and there are
  tentative records, offer a review to the user.

### Sync

- The hook `SessionStart` runs `sync.sh pull`. The hook `Stop` runs `sync.sh push` after
  each reply. Do not commit or push this repository yourself. Exceptions: the user tells
  you to, a conflict makes it necessary, or you do an update (section "Updates").
- If the SessionStart hook shows a WARNING (rebase conflict, team file not committed),
  tell the user.
- A file `<file>.<host>.md` next to a memory file is a version from a different machine
  that `sync.sh` could not merge. When you work on that topic, merge it into the primary
  file, delete it, and tell the user.

### Updates of claude-memory-sync

- If the SessionStart hook shows `UPDATE: claude-memory-sync vX.Y.Z is available`, do
  the update. The instructions are in `UPDATE.md` of the new version. The notice gives
  the command that shows them: `git -C ~/.claude/claude-memory show vX.Y.Z:UPDATE.md`.
  Read them first, then follow them.
- If the SessionStart hook shows `SETUP: ...`, run `~/.claude/claude-memory/sync.sh
  setup`, as `~/.claude/claude-memory/UPDATE.md`, section "Setup of a machine", tells.
- If the user asks for an update of claude-memory-sync, run
  `~/.claude/claude-memory/sync.sh version`. Then follow `UPDATE.md` of the latest
  release.
