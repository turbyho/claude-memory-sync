## Claude memory: synced repository

The auto memory of some projects is in the git repository `~/.claude/claude-memory`. A
sync script copies it to all machines and to all persons that use the repository. Full
description: `~/.claude/claude-memory/README.md`. Full procedure: skill
`memory-lifecycle`. Load the skill before you write, review or invalidate a record.

### Roles

| Role | Location | Who uses it |
|---|---|---|
| Team | `~/.claude/claude-memory/projects/<name>/team/` | All persons that use the repository |
| Personal | the memory directory of the session (`projects/<name>/users/<user>/`) | One person, on all machines of the person |
| Local | `<memory directory>/hosts/<host>/` | One person, on one machine |

- The memory directory of the session is a symlink to `projects/<name>/users/<user>/` if
  the personal memory is enabled. If it is a real directory, the personal memory is not
  synced. If the user asks to enable it, run
  `~/.claude/claude-memory/sync.sh enable <project-dir>`.
- The SessionStart hook gives you the index of the local memory and of the team memory.
- A line in `## Groups` of `MEMORY.md` can link to a shared topic for more than one
  project: `~/.claude/claude-memory/shared/<topic>/` (team) or
  `~/.claude/claude-memory/users/<user>/shared/<topic>/` (personal).
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
- If `<!-- last-review: ... -->` in `MEMORY.md` is older than 14 days and there are
  tentative records, offer a review to the user.

### Sync

- The hook `SessionStart` runs `sync.sh pull`. The hook `Stop` runs `sync.sh push` after
  each reply. Do not commit or push this repository yourself. Exceptions: the user tells
  you to, or a conflict makes it necessary.
- If the SessionStart hook shows a WARNING (rebase conflict, team file not committed),
  tell the user.
- A file `<file>.<host>.md` next to a memory file is a version from a different machine
  that `sync.sh` could not merge. When you work on that topic, merge it into the primary
  file, delete it, and tell the user.
