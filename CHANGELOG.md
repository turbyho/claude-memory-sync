# Changelog

Each release is a git tag `vX.Y.Z`. Claude reads this file during an update and tells the
user the changes. Write the changes for the user: what is new, what is different, what
the user must do.

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
