# Changelog

Each release is a git tag `vX.Y.Z`. Claude reads this file during an update and tells the
user the changes. Write the changes for the user: what is new, what is different, what
the user must do.

## v0.2.0 - 2026-10-07

- More memory repositories: a project can use a different repository than the main
  repository, for example the repository of a company team. The clones are in
  `~/.claude/claude-memory.d/<alias>/`.
- New commands: `sync.sh add-repo <alias> <url>`, `sync.sh repos`,
  `sync.sh move [dir] <alias>`, and `sync.sh enable [dir] --repo <alias>`.
- `sync.sh add-repo` writes the repository into `users/<user>/repos.conf`. Your other
  machines clone it at their next session.
- When a project moves to a different repository, the SessionStart hook links its memory
  to the new place on each machine with a clone of that repository.
- Fixed: when the sync adopted a local memory directory with subdirectories (for example
  `invalid/`), it copied a subdirectory as a file `<name>.<host>.md`. Now it merges the
  subdirectories.
- Nothing to do for the user. The setup of the machines does not change.

## v0.1.0 - 2026-10-07

First release.

- Memory roles for each project: team (`projects/<name>/team/`), personal
  (`users/<user>/`, on all machines of the person) and local
  (`users/<user>/hosts/<host>/`, one machine)
- Each person enables a project for the personal memory (`sync.sh enable`). The state
  goes to all machines of the person.
- Team memory: the index comes from the frontmatter of the records. The PreToolUse hook
  blocks absolute paths and links outside the project.
- Shared topics for more than one project: team (`shared/<topic>/`) and personal
  (`users/<user>/shared/<topic>/`)
- Skill `memory-lifecycle`: tentative, confirmed and invalid records, review, roles,
  shared topics
- Updates: the SessionStart hook tells Claude about a new release. `sync.sh update`
  merges it, `sync.sh setup` sets up a machine, `sync.sh version` shows the versions.
