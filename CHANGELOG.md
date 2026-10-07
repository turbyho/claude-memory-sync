# Changelog

Each release is a git tag `vX.Y.Z`. Claude reads this file during an update and tells the
user the changes. Write the changes for the user: what is new, what is different, what
the user must do.

## v0.3.9 - 2026-10-07

- README.md, SKILL.md and the tests use invented examples: the projects `recipe-book`
  (private) and `web-shop` (work), facts about pnpm and a local database, the personal
  shared topic `photo-archive`.
- Nothing to do for the user.

## v0.3.8 - 2026-10-07

- README.md: clearer examples. The work repository on the git server is
  `team/work-claude-memory`, and its alias is `work`. Section 2.2 explains the alias.
- Nothing to do for the user.

## v0.3.7 - 2026-10-07

- README.md is new: it is only for people, with clear parts. Section 2 shows the full
  structure (repositories, projects, team, personal and local memory, shared topics,
  states), section 3 the possible setups (one person, private and work, team).
- New file INSTALL.md: the installation procedure for Claude. The installation prompt
  now refers to INSTALL.md.
- Removed: the migration of an older memory layout (`tools/migrate.sh`,
  `local-candidates.sh`, `relink.sh`, `visible-notes.sh`). That layout was never public.
  `tools/validate.sh` stays.
- Nothing to do for the user.

## v0.3.6 - 2026-10-07

- Fixed: `tools/relink.sh` did not change the memory symlinks on a second machine after
  a migration. The symlinks are absolute: after the rename of the old clone and the clone
  of the new repository at the same path, they point to the project directory of the new
  repository, not to the old clone. Now `relink.sh` also changes these symlinks.
- Nothing to do for the user.

## v0.3.5 - 2026-10-07

- Fixed: the release v0.3.4 has the wrong `VERSION` (0.3.3). Use v0.3.5. The content of
  v0.3.5 is the same as v0.3.4.

## v0.3.4 - 2026-10-07

- Fixed: `tools/relink.sh` looked for a project only in the main repository. A project
  in a project repository (`~/.claude/claude-memory.d/<alias>`) stayed linked to the old
  clone. Now it looks in all repositories, and reports a project that it cannot find.
- README.md, section 9, step 6: the procedure for each other machine after a migration.
- Nothing to do for the user.

## v0.3.3 - 2026-10-07

- New command `sync.sh rename-repo <old alias> <new alias> [<url>]`: renames the alias
  of a memory repository and sets its new URL, for example after a rename on the git
  server. It relinks the projects. Your other machines do the same at their next session
  (`users/<user>/repos.renamed`).
- `sync.sh pull` sets the URL of each clone to the URL in `repos.conf`.
- Nothing to do for the user.

## v0.3.2 - 2026-10-07

- Fixed: `tools/migrate.sh` wrote the date of the migration into `Last review:`. Claude
  then did not offer a review of the tentative records for 14 days, although nobody did
  a review. Now the default is `Last review: never`. Use `--reviewed` if you did a review
  of all records before the migration.
- `Last review: never` tells Claude to offer a review if there are tentative records.
- What to do: if `tools/migrate.sh` of an older release migrated your memory, the update
  asks you if it can set `Last review: never` (UPDATE.md, step for v0.3.2).

## v0.3.1 - 2026-10-07

- Fixed: `sync.sh status`, `enable`, `disable` and `move` without a directory used the
  memory repository as the project, not the current directory. A relative path was also
  wrong. Now the default directory and a relative path are from the directory where you
  start `sync.sh`.
- Fixed: Claude did not see the date of the last review and the rules line in
  `MEMORY.md`, because Claude Code removes HTML comments before it loads the file. They
  are now visible lines: `Last review: <date>` and `Rules: ...`.
- New tool `tools/visible-notes.sh <memory repo>`: changes the comments in existing
  `MEMORY.md` files to visible lines. The update to v0.3.1 runs it.

## v0.3.0 - 2026-10-07

- All memory repositories are equal. Each one has the tool, thus a repository can be the
  main repository of one person and a project repository of an other person. A person in
  a team can use the team repository as the main repository, without a private one
  (README.md, section 2.2).
- `sync.sh add-repo` puts the tool into a repository that has none. A repository keeps
  its own version of a file that the tool also has (for example `README.md`).
- `sync.sh update` puts a new release also into your project repositories with an older
  tool. A repository without write access does not change.
- `sync.sh version` shows the tool version of each project repository.
- What to do: after the update to v0.3.0, run `sync.sh update` one more time. It puts the
  tool into your project repositories.

## v0.2.1 - 2026-10-07

- New tools for the migration of an older memory (README.md, section 9):
  `tools/migrate.sh`, `tools/validate.sh`, `tools/local-candidates.sh`,
  `tools/relink.sh`.
- `tools/validate.sh <memory repo>` checks a memory repository: index links, index
  lines, frontmatter, team memory.
- Automatic tests in `tests/` (README.md, section 10).
- `sync.sh` does not change. Nothing to do for the user.

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
