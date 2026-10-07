# claude-memory-sync

Keep the Claude Code auto memory in a git repository, and use it on all your machines
and in your team.

- Three roles of memory for each project: team, personal (one person, all machines of
  the person), local (one machine)
- Each person enables the projects that the person wants to sync
- Shared topics for facts that apply to more than one project
- Memory lifecycle (draft): tentative, confirmed and invalid records, with a review by
  Claude
- One POSIX shell script and three Claude Code hooks. The only dependency is `git`.
- Linux and macOS

> WARNING: THIS REPOSITORY IS A TEMPLATE. PUT YOUR MEMORY ONLY INTO A PRIVATE COPY OF IT.
> THE MEMORY CAN CONTAIN NAMES, PATHS AND NOTES ABOUT YOUR PROJECTS. DO NOT PUSH IT TO A
> PUBLIC REMOTE. EACH PERSON WITH ACCESS TO THE COPY CAN READ ALL ITS MEMORY.

Contents:

1. [Quick start with Claude](#1-quick-start-with-claude)
2. [Prompts for daily use](#2-prompts-for-daily-use)
3. [The problem](#3-the-problem)
4. [How it works](#4-how-it-works)
5. [Memory roles](#5-memory-roles)
6. [Manual setup](#6-manual-setup)
7. [Daily use](#7-daily-use)
8. [Disable a project](#8-disable-a-project)
9. [Shared topics](#9-shared-topics)
10. [Memory lifecycle](#10-memory-lifecycle)
11. [Conflicts](#11-conflicts)
12. [Troubleshooting](#12-troubleshooting)
13. [Remove from a machine](#13-remove-from-a-machine)
14. [Instructions for Claude: installation](#14-instructions-for-claude-installation)
15. [Development](#15-development)

## 1. Quick start with Claude

Claude Code can do the installation for you. Section 14 gives Claude the procedure.

### 1.1 The first person

1. On your git server, make an empty PRIVATE repository for the memory, for example
   `git@git.example.com:team/claude-memory.git`. Give access only to the persons that
   must see the memory. For one person, give access only to yourself.

2. Make sure that `git clone` of that repository operates without a password prompt. Use
   an SSH key without a passphrase, or an SSH agent. The hooks cannot ask for a password.

3. Start Claude Code in your home directory and give it this prompt. Change the URL and
   the project directories:

   ```text
   Install claude-memory-sync from https://git.montyho.com/turbyho/claude-memory-sync.
   Clone it to a temporary directory, read the section "Instructions for Claude:
   installation" in its README.md, and do the procedure.

   The memory repository is git@git.example.com:team/claude-memory.git.
   It is a private repository.
   Enable the memory for these projects: ~/work/example-app, ~/work/example-api.
   ```

4. Read the report of Claude. It tells you which files it changed, and where the backups
   are.

5. Start a new Claude Code session. Claude Code loads the hooks only at the start of a
   session.

### 1.2 Each other machine, and each other person

Give Claude the same prompt. A person who joins a team gives the list of the projects
that the person wants to use. On a second machine of the same person, the list is not
necessary: the projects of the person are enabled already.

To enable one more project later, start Claude Code in that project and say: "Enable the
memory for this project."

## 2. Prompts for daily use

You can ask Claude to do these tasks in any language. Some examples:

| Task | Prompt |
|---|---|
| Enable the memory | "Enable the memory for this project." |
| Show the state | "Show the memory status of this project." |
| Show all projects | "Which projects use the memory repository, and which persons?" |
| Disable the memory | "Disable my memory for this project." |
| Team memory | "Save to the team memory: the integration tests need the docker service." |
| Local memory | "Remember for this machine: the debug probe is on /dev/ttyACM0." |
| Show the local memory | "What is in the local memory of this machine?" |
| Team shared topic | "Make a team shared topic `test-server` for the projects example-app and example-api, and move the facts about the test server into it." |
| Personal shared topic | "Make a personal shared topic `nas` for all my projects that use the NAS, and move my NAS records into it." |
| Review the memory | "Review the tentative memory records." |
| Confirm a record | "The record about the build with ninja is correct. Promote it." |
| Invalidate a record | "The record about the build with ninja is not correct any more: make works again since commit abc123. Invalidate it." |
| Check a claim | "Is the claim that the API needs a token in the invalid memory records?" |
| Who changed a record | "Show the history of the memory record about the build." |
| History | "Show the changes to the memory of this project in the last week." |
| Merge a conflict file | "Merge the `.<host>.md` files in the memory of this project." |
| Other memory repository | "Add the memory repository `work` (git@git.example.com:team/claude-memory.git), and move this project to it." |
| Update the tool | "Update claude-memory-sync." |

## 3. The problem

### 3.1 What the auto memory is

While Claude works in a project, it writes notes for later sessions: the build command
that works, a trap in the test setup, a decision of the team, your preferences. Claude
Code calls these notes the auto memory. Each note is one Markdown file. The index
`MEMORY.md` has one line for each note, and Claude Code loads it at the start of each
session.

Claude Code keeps the auto memory of each project in this directory:

```
~/.claude/projects/<slug>/memory/
```

Claude Code makes `<slug>` from the absolute path of the project. Each character other
than `A-Z a-z 0-9` becomes `-`. In a git repository, the path is the top directory of the
main working tree.

### 3.2 The memory stays on one machine

The auto memory is not in the git repository of the project, and Claude Code does not
sync it. The user `alice` has the project `example-app` on three machines:

| Machine | Project path | Memory directory |
|---|---|---|
| macOS laptop | `/Users/alice/work/example-app` | `~/.claude/projects/-Users-alice-work-example-app/memory` |
| Linux workstation | `/home/alice/src/example-app` | `~/.claude/projects/-home-alice-src-example-app/memory` |
| Windows desktop | `C:\Users\alice\dev\example-app` | `%USERPROFILE%\.claude\projects\C--Users-alice-dev-example-app\memory` |

The Windows row shows the problem only. `sync.sh` does not support native Windows yet
(section 6).

Thus Claude Code has three memories for one project:

- Claude learns a fact on the laptop. On the workstation, Claude does not know it, and
  learns it again, possibly with a different result.
- You correct an incorrect note on one machine. On the other machines, the incorrect note
  stays.

### 3.3 The memory stays with one person

The colleague `bob` works on the same project. His Claude learns the same build trap
again, because the memory of `alice` is on her machines only. A team has no place for
the facts that all persons need.

### 3.4 A copy of the directory is not sufficient

You can try to sync `~/.claude/projects/` with a file sync tool (rsync, a cloud drive).
That does not solve the problem:

- The slug comes from the path. The three machines use three different directory names
  for one project, thus the copies do not meet.
- Some notes are correct on one machine only, for example
  `/opt/toolchains/arm-gcc-13/bin` or `COM3`. On a different machine, such a note is
  incorrect.
- Two machines can change one file at the same time. A file sync tool keeps one version,
  or makes a conflict copy that Claude does not see.
- There is no history. You cannot see who changed a note, and you cannot undo a change.

### 3.5 More problems of the auto memory

- A fact that applies to two projects (for example, the access to a test server) is
  written two times, and the two copies become different.
- Claude writes a conclusion into the memory at once, and all later sessions use it as
  true. An incorrect conclusion stays until somebody finds it.

### 3.6 What this repository does

| Problem | Solution | Section |
|---|---|---|
| The memory stays on one machine | A git repository, synced by hooks | 4 |
| Different paths on each machine | A project name from the git remote, not from the path | 4.2 |
| The memory stays with one person | The team memory of each project | 5.1 |
| Facts for one machine only | The local memory of each machine | 5.3 |
| Facts for more than one project | Shared topics | 9 |
| No history | Git: each change is a commit with its author | 7 |
| Incorrect conclusions stay | Tentative, confirmed and invalid records, and a review | 10 |

## 4. How it works

The sync gives each project a name that does not come from the path: the name of its git
remote. On each machine, the memory directory of the project is a symlink to the personal
memory of the person in the repository:

```
alice, macOS:  ~/.claude/projects/-Users-alice-work-example-app/memory  --+
alice, Linux:  ~/.claude/projects/-home-alice-src-example-app/memory    --+-- symlink
                                                                          v
~/.claude/claude-memory/projects/example-app/
    team/                          <- team memory: all persons
        build-uses-ninja.md
        invalid/                   <- known false team records
    users/alice/                   <- personal memory of alice, all her machines
        MEMORY.md                  <- index, loaded at session start
        release-checklist.md
        invalid/                   <- known false records
        hosts/laptop/              <- local memory of one machine of alice
    users/bob/                     <- personal memory of bob
~/.claude/claude-memory/shared/test-server/        <- team shared topic (section 9)
~/.claude/claude-memory/users/alice/shared/nas/    <- personal shared topic of alice
```

Git syncs the repository between all machines and all persons.

### 4.1 Repository layout

| Path | Content |
|---|---|
| `projects/<name>/team/` | Team memory of a project (section 5.1). |
| `projects/<name>/users/<user>/` | Personal memory of one person (section 5.2). `MEMORY.md` is the index. |
| `projects/<name>/users/<user>/hosts/<host>/` | Local memory of one machine (section 5.3). |
| `projects/_home/` | Memory of the sessions that start in the home directory. |
| `shared/<topic>/` | Team shared topics (section 9). |
| `users/<user>/shared/<topic>/` | Personal shared topics (section 9). |
| `CLAUDE-MEMORY.md` | Instructions for Claude. You import them into `~/.claude/CLAUDE.md`. |
| `users/<user>/repos.conf` | The other memory repositories of a person (section 4.7). |
| `skills/memory-lifecycle/` | Skill for Claude: roles and lifecycle (sections 5 and 10), with templates. |
| `team-memory-check.default` | Forbidden patterns in the team memory (section 5.1). |
| `sync.sh` | Sync script (POSIX sh). The hooks call it. |
| `VERSION`, `CHANGELOG.md` | Version of the tool and its changes (section 7.1). |
| `UPDATE.md` | Instructions for Claude: update of the tool and setup of a machine. |
| `tools/` | Migration of an older memory (section 6.4), and a check of a memory repository. |
| `tests/` | Automatic tests of the tool (section 15). |

### 4.2 Project name

The project name is the same on each machine and for each person, because the script
does not use the path:

1. The name of the git remote `origin`: `git@git.example.com:corp/example-app.git`
   gives `example-app`.
2. If there is no remote: the name of the git top directory.
3. If the directory is not in git: the name of the directory.
4. The home directory gives `_home`.

Two projects with the same remote name share one memory. If that is not correct, rename
the remote or the directory of one of them.

A session that starts in a subdirectory or in a git worktree of a project uses the same
memory. Claude Code and `sync.sh` make the slug from the top directory of the main
working tree.

### 4.3 Person and machine names

| Name | Command | Source |
|---|---|---|
| `<user>` | `sync.sh user` | The part before `@` of `git config user.email` in the repository. The env var `CLAUDE_MEMORY_USER` overrides it. |
| `<host>` | `sync.sh host` | `scutil --get LocalHostName` on macOS, `hostname -s` on Linux. The env var `CLAUDE_MEMORY_HOST` overrides it. |

`<user>` must be the same on all machines of a person. Use the same `user.email` on all
your machines, or set `CLAUDE_MEMORY_USER`. To set an env var for Claude Code, use the
`env` key of `~/.claude/settings.json`.

### 4.4 Enabled projects

Each person enables the projects that the person wants to sync. A project is enabled for
a person when the directory `projects/<name>/users/<user>/` is in the repository. Thus
when you enable a project on one machine, git sends that state to all your machines.

| Command | What it does |
|---|---|
| `sync.sh enable [dir]` | Makes `users/<user>/` (and `team/` if it does not exist), moves the local memory into it, makes the symlink, commits and pushes. |
| `sync.sh disable [dir]` | Replaces your symlinks with local copies, removes `users/<user>/`, commits and pushes. The team memory and the memory of other persons do not change. |
| `sync.sh status [dir]` | Shows the name, the person, the machine and the state of the project. |
| `sync.sh list` | Shows the projects, their repository and the persons that use them. |
| `sync.sh add-repo`, `repos`, `move`, `enable --repo` | More memory repositories (section 4.7). |

`dir` is the project directory. The default is the current directory.

The team memory of a project is available to all persons, also to a person who did not
enable the project.

### 4.5 Hooks

| Hook | Command | What it does |
|---|---|---|
| `SessionStart` | `sync.sh pull` | Pulls the repository. Links the memory directory of the session if the project is enabled for you. Gives the index of the local memory and of the team memory to Claude. Shows warnings (rebase conflict, team file not committed) and notices (new release, setup of the machine; section 7.1). |
| `Stop` (async) | `sync.sh push` | After each reply: commits all changes ("Update memory from <user>@<host>") and pushes. A team file with a forbidden pattern stays out of the commit. |
| `PreToolUse` (`Write`, `Edit`, `MultiEdit`) | `sync.sh check-team` | Blocks a write into the team memory that contains a forbidden pattern (section 5.1). |

The hooks are global, but they change nothing in a project that is not in the
repository.

The script ignores network errors (ssh `ConnectTimeout=5`, `BatchMode=yes`). If the server
is not available, Claude uses the local copy, and the next `push` sends the changes.

### 4.6 Linking

When the script links an enabled project, it looks at the memory directory of the session:

| State of `~/.claude/projects/<slug>/memory` | Action |
|---|---|
| Symlink | Nothing. |
| Does not exist | Makes the symlink. |
| Real directory | Copies the local files into `users/<user>/`, then makes the symlink. |
| Symlink to a removed personal memory, project now in a different repository | The project moved (`sync.sh move`). Makes the symlink to the new place. |
| Symlink to a removed personal memory, project in no repository of this machine | You disabled the project, or it moved to a repository without a clone on this machine. Makes a local copy from the git history, and tells Claude why. |

If a local file is different from the file in the repository, the script keeps the local
version as `<file>.<host>.md` next to the repository version. The old local directory
goes to `~/.claude/memory-backup/<slug>.<time>`. Merge the `<host>` file by hand, or ask
Claude to do it. Then delete the `<host>` file.

### 4.7 More memory repositories

Projects can use different memory repositories. Example: the work projects use the
repository of the company team, and the private projects use your private repository.

- The main repository `~/.claude/claude-memory` holds the tool. The hooks run its
  `sync.sh`. The projects that have no other repository are in it.
- Each other repository has a clone in `~/.claude/claude-memory.d/<alias>/`. It can be a
  copy of this template, or a repository with only memory (`projects/`, `users/`,
  `shared/`). The tool in it is not used.
- A project is in the repository that has the directory `projects/<name>/`. Each project
  is in one repository.
- Shared topics link only projects of the same repository.

| Command | What it does |
|---|---|
| `sync.sh add-repo <alias> <url>` | Clones the repository, and adds it to `users/<user>/repos.conf` in the main repository. Your other machines clone it at their next session. |
| `sync.sh enable [dir] --repo <alias>` | Enables a new project in that repository. |
| `sync.sh move [dir] <alias>` | Moves the project (team memory and the personal memory of all persons) to that repository. `main` is the main repository. Each person needs a clone of the new repository. |
| `sync.sh repos` | Shows the repositories and their projects. |

Example: move two work projects to the repository of the team:

```sh
~/.claude/claude-memory/sync.sh add-repo work git@git.example.com:team/claude-memory.git
~/.claude/claude-memory/sync.sh move ~/work/example-app work
~/.claude/claude-memory/sync.sh move ~/work/example-api work
```

The hooks pull and push all repositories, and the PreToolUse hook checks the team memory
of all repositories. The notices about a new release apply only to the main repository.

## 5. Memory roles

| Role | Location | Who uses it | Loaded at session start |
|---|---|---|---|
| Team | `projects/<name>/team/` | All persons | Index made by the SessionStart hook |
| Personal | `projects/<name>/users/<user>/` | One person, all machines of the person | `MEMORY.md` (Claude Code) |
| Local | `projects/<name>/users/<user>/hosts/<host>/` | One person, one machine | `INDEX.md` (SessionStart hook) |

### 5.1 Team memory

The team memory holds facts about the project that are correct for all persons on all
machines: the build, the tests, the conventions, the traps.

- Claude writes a team record only after your approval, because all persons see it.
- The team memory has no index file. The SessionStart hook makes the index from the
  frontmatter of the records (`name`, `description`, `status`). Thus two persons cannot
  get a conflict in an index.
- A team record must not contain absolute paths, home directory paths, links outside the
  project, or machine names. The PreToolUse hook blocks such a write, and `sync.sh push`
  keeps such a file out of the commit. The patterns are in `team-memory-check.default`.
  To change them for your team, copy the file to `.memory-check` in the root of the
  repository.
- To check files by hand, or in CI: `sync.sh lint <file>...`

### 5.2 Personal memory

The personal memory holds the facts of one person: preferences, work methods, decisions,
corrections. It is the same on all machines of the person. This is the auto memory of
Claude Code: the memory directory of the session is a symlink to it.

### 5.3 Local memory

Some facts are correct on one machine only, for example:

- `/opt/toolchains/arm-gcc-13/bin` is the toolchain on the workstation.
- The debug probe is on `/dev/ttyACM0` on the laptop.
- The test data is in `~/data/example-app`, outside the project.

The local memory of each machine is in `users/<user>/hosts/<host>/`. Absolute paths and
links outside the project are permitted there. The SessionStart hook gives the first 100
lines of `hosts/<host>/INDEX.md` to Claude, thus the local records do not use the space of
`MEMORY.md`. Git syncs the local memory as a backup, but only its machine uses it.

### 5.4 How Claude selects the role

1. Local: the record contains an absolute path, a path in the home directory, a link
   outside the project, a device name, or a setting of the machine.
2. Personal: the record is about you (preference, work method, decision, correction).
3. Claude asks you "team memory or personal memory?": the record is a fact about the
   project that can be correct for all persons.
4. Personal: all other records.

Claude asks only in case 3. If a fact has a general part and a machine part, Claude
writes two records: the general fact as team or personal, the machine detail as local.

If a team or personal fact applies to more than one project, Claude writes it into a
shared topic of its role (section 9), not into one project and not as a copy into each
project. A local record always stays in the project.

### 5.5 Privacy

Each person with access to the repository can read all memory: the team memory, and the
personal and local memory of all persons. Do not write private information into the
memory. If you need memory that only you can read, make a second repository for one
person, and use it on a different machine account.

## 6. Manual setup

Use this section if you do not want Claude to do the installation (section 1).

Requirements:

- Linux or macOS. Native Windows is not supported yet. In WSL, use the Linux procedure
  (not tested).
- `git` 2.31 or later, with `user.email` set
- SSH access to your git server without a password prompt
- Recommended: `jq` or `python3` to read the hook input. Without them, the PreToolUse
  check does not operate, but `sync.sh push` still keeps forbidden team files out of the
  commit.

### 6.1 The first person: make the memory repository

1. On your git server, make an empty PRIVATE repository, for example
   `git@git.example.com:team/claude-memory.git`.

2. Clone this template into `~/.claude/claude-memory`, and make the memory repository the
   `origin`:

   ```sh
   git clone https://git.montyho.com/turbyho/claude-memory-sync.git ~/.claude/claude-memory
   cd ~/.claude/claude-memory
   git reset -q --hard "$(git tag -l 'v*' --sort=-v:refname | head -n 1)"   # latest release
   git remote rename origin upstream
   git remote add origin git@git.example.com:team/claude-memory.git
   git push -u origin main
   ```

   The remote `upstream` lets you get new versions of the script (section 7).

3. Do the steps in section 6.3.

### 6.2 Each other machine, and each other person

1. Clone the memory repository, and add the remote `upstream`:

   ```sh
   git clone git@git.example.com:team/claude-memory.git ~/.claude/claude-memory
   git -C ~/.claude/claude-memory remote add upstream https://git.montyho.com/turbyho/claude-memory-sync.git
   ```

2. Do the steps in section 6.3.

### 6.3 Hooks, instructions and skill (each machine)

1. Set up the machine:

   ```sh
   ~/.claude/claude-memory/sync.sh setup
   ```

   The command does these steps. Each step changes nothing if it is done already:

   - Adds the three hooks to `~/.claude/settings.json`. It makes a backup first, and keeps
     all other keys and hooks. It needs `jq` or `python3`.
   - Adds the import line `@~/.claude/claude-memory/CLAUDE-MEMORY.md` to
     `~/.claude/CLAUDE.md`. Claude Code loads the instructions at the start of each
     session.
   - Makes the symlink `~/.claude/skills/memory-lifecycle`. Thus `git pull` updates the
     skill.
   - Writes the setup version to `~/.claude/claude-memory-setup`.

   For reference, the hooks that `setup` adds:

   ```json
   "hooks": {
     "SessionStart": [
       { "hooks": [{ "type": "command", "command": "~/.claude/claude-memory/sync.sh pull",
                     "timeout": 20 }] }
     ],
     "Stop": [
       { "hooks": [{ "type": "command", "command": "~/.claude/claude-memory/sync.sh push",
                     "timeout": 30, "async": true }] }
     ],
     "PreToolUse": [
       { "matcher": "Write|Edit|MultiEdit",
         "hooks": [{ "type": "command", "command": "~/.claude/claude-memory/sync.sh check-team",
                     "timeout": 10 }] }
     ]
   }
   ```

2. Make sure that the person name is correct. It must be the same on all your machines:

   ```sh
   ~/.claude/claude-memory/sync.sh user
   ```

3. Enable the projects that you want to sync. Do this on one of your machines only:

   ```sh
   ~/.claude/claude-memory/sync.sh enable ~/work/example-app
   ~/.claude/claude-memory/sync.sh enable ~              # memory of the home directory
   ```

   On your other machines, the script links the project at the next session in it.

4. Do a check:

   ```sh
   ~/.claude/claude-memory/sync.sh version
   ~/.claude/claude-memory/sync.sh status ~/work/example-app
   git -C ~/.claude/claude-memory status -sb      # "## main...origin/main", no changes
   ```

   Then start a new Claude Code session in the project and ask: "What is in your memory?"

### 6.4 Migrate an older memory

If you synced the memory before with an older layout (`projects/<name>/` with the records,
and shared directories at the root that the projects link with symlinks), migrate it:

1. Rename the old clone, then make the new memory repository (section 6.1). Do not set
   up the machine yet:

   ```sh
   mv ~/.claude/claude-memory ~/.claude/claude-memory-old
   ```

   The tools below are in `~/.claude/claude-memory/tools/` of the new repository.
2. Find the records that describe one machine only, and write them into a file, one line
   `<project>/<file>.md` each:

   ```sh
   ~/.claude/claude-memory/tools/local-candidates.sh ~/.claude/claude-memory-old > candidates.txt
   ```

   Read each candidate. Only a record that describes one machine is local. A general fact
   with a path as an example stays personal.
3. Migrate. The script reads the old repository, and writes into the new one:

   ```sh
   ~/.claude/claude-memory/tools/migrate.sh --old ~/.claude/claude-memory-old --new ~/.claude/claude-memory \
     --user "$(~/.claude/claude-memory/sync.sh user)" \
     --host "$(~/.claude/claude-memory/sync.sh host)" --local local.txt
   ```

   - Records with `metadata.verified` become `confirmed`, the other records `tentative`.
     Use `--status confirmed` or `--status tentative` to give all records one state.
   - Each shared directory becomes a personal shared topic `users/<user>/shared/<dir>/`.
4. Do a check, read the result, then commit and push:

   ```sh
   ~/.claude/claude-memory/tools/validate.sh ~/.claude/claude-memory
   ```

5. Point the memory symlinks of each machine to the new repository, then set up the
   machine (section 6.3):

   ```sh
   ~/.claude/claude-memory/tools/relink.sh ~/.claude/claude-memory-old ~/.claude/claude-memory "$(~/.claude/claude-memory/sync.sh user)"
   ```

Keep the old repository until all your machines use the new one.

### 6.5 Other location of the repository

The script finds the repository from its own location, and `sync.sh setup` uses that
location for the hooks, the import line and the skill symlink. As an alternative, set the
env var `CLAUDE_MEMORY_REPO`.

## 7. Daily use

Claude reads and writes the memory as usual. The hooks sync it. You do not have to do
more. For the prompts, see section 2.

- Enable a new project: `sync.sh enable <dir>`
- See the history: `git -C ~/.claude/claude-memory log --stat`
- See who changed the team memory: `git -C ~/.claude/claude-memory log --format='%an %ad %s' -- projects/<name>/team`
- Undo a bad memory change: `git -C ~/.claude/claude-memory revert <commit>`. The next
  `push` sends it.
- Sync by hand: `sync.sh pull < /dev/null` and `sync.sh push`.
- Show the versions: `sync.sh version`

### 7.1 Updates of the tool

The tool (`sync.sh`, `CLAUDE-MEMORY.md`, the skill, the templates) is in the memory
repository. The remote `upstream` is this repository. A release is a git tag `vX.Y.Z`.

1. One time in 24 hours, `sync.sh pull` gets the release tags from `upstream`. If a
   release is newer than the `VERSION` of the memory repository, the SessionStart hook
   tells Claude: `UPDATE: claude-memory-sync vX.Y.Z is available`. The notice gives the
   command that shows `UPDATE.md` of the new release.
2. Claude tells you, reads `UPDATE.md` of the new release, and does the update. The
   instructions are in `CLAUDE-MEMORY.md`, section "Updates".
3. `sync.sh update` merges the release tag into the memory repository, pushes it, and runs
   `sync.sh setup` on this machine.
4. The other machines and persons get the new version with their next `sync.sh pull`. If
   the release changes the setup of a machine, their SessionStart hook shows `SETUP`, and
   Claude runs `sync.sh setup` there.

To update by hand: `~/.claude/claude-memory/sync.sh update`, or the prompt "Update
claude-memory-sync."

The template does not contain files in `projects/`, `users/` or `shared/`, thus an update
does not touch the memory. If you changed a file of the tool in your copy (for example the
skill), an update can cause a conflict. `sync.sh update` then stops and changes nothing.
Claude shows you the two changes and asks how to merge them (`UPDATE.md`, section
"Conflicts").

> CAUTION: AN UPDATE RUNS NEW CODE FROM `upstream` ON ALL YOUR MACHINES. SET `upstream`
> ONLY TO A REPOSITORY THAT YOU TRUST.

### 7.2 Publish a new release (maintainers)

Do these steps in the repository of the tool, not in a memory repository:

1. Write the changes into `CHANGELOG.md`, in a new section `## vX.Y.Z - <date>`. Write
   them for the user: what is new, what is different, what the user must do.
2. Write the new version into `VERSION`.
3. If the release changes the setup of a machine (hooks, import line, skill symlink),
   change `setup()` in `sync.sh`, and increase `SETUP_VERSION`.
4. If the update needs more steps (for example a change of the memory layout), add them
   to `UPDATE.md`, section "Steps for each release".
5. Commit, tag and push:

   ```sh
   git commit -am "Release vX.Y.Z"
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The memory repositories find the release within 24 hours.

## 8. Disable a project

```sh
~/.claude/claude-memory/sync.sh disable ~/work/example-app
```

This disables only your personal memory of the project. It stays on each of your machines
as a local directory. Git keeps the old versions in the history. The team memory and the
memory of other persons do not change.

To remove the full project with its team memory, remove `projects/<name>/` with
`git rm -r`, and tell the team first.

## 9. Shared topics

Some facts apply to more than one project, for example the access to a test server, or the
schema of a database. A shared topic holds such facts one time. Each project that uses the
topic has a link to it.

| Type | Location | For | Check of the team memory |
|---|---|---|---|
| Team shared topic | `shared/<topic>/` | Facts that are correct for all persons | Yes (section 5.1) |
| Personal shared topic | `users/<user>/shared/<topic>/` | Facts of one person, for example the access to a home server with paths in the home directory | No |

A local record (section 5.3) is never in a shared topic.

### 9.1 How Claude uses the topics

- When Claude writes a team or personal fact that applies to more than one project, it
  writes the fact into a shared topic of the same role.
- If no topic fits, Claude proposes a new topic: its name, its role and its projects.
  Claude makes the topic only after your approval.
- To make a topic and move existing records into it, use a prompt of section 2. Claude
  moves the records, and changes the links in `MEMORY.md` of each project.

### 9.2 Structure

- `<topic>/README.md` gives the rules of the topic and the list of the projects that use
  it.
- The topic has no index file. Claude finds its records through the topic line in
  `MEMORY.md`, and with Grep for `^description:` in the topic directory.
- Invalid records go to `<topic>/invalid/`.
- The repository contains no symlinks. The link is a path in `MEMORY.md`, thus it
  operates on each system, also where git cannot make symlinks.

### 9.3 Links in MEMORY.md

`MEMORY.md` of each project that uses the topic has one topic line in `## Groups`: the
link to the topic directory, and the key words of all its records. Below it, a small
topic (10 records or less) can have one indented line for each record:

```
- [Test server](~/.claude/claude-memory/shared/test-server/) - shared: SSH access, database schema
  - [SSH access](~/.claude/claude-memory/shared/test-server/ssh-access.md) - user, key, jump host
```

The topic line is necessary. The record lines are optional. If a topic has record lines,
they must list all its records, thus a new record of the topic changes `MEMORY.md` of
each project that uses the topic. Without record lines, a new record changes only the
topic directory.

`MEMORY.md` is personal. For a team shared topic, each person adds the topic line to the
own `MEMORY.md`. Claude does not change the personal memory of a different person.

### 9.4 Make a topic by hand

1. Make the directory, for example `mkdir -p ~/.claude/claude-memory/shared/test-server/invalid`.
2. Write `<topic>/README.md` with the rules and the list of the projects.
3. Move the records into the topic directory. Do not change their names.
4. In `MEMORY.md` of each project: remove the lines of the moved records, and add the
   topic line in `## Groups`.

## 10. Memory lifecycle

> This part is a draft. The rules can change.

Without this part, Claude writes a fact into the memory at once, and all later sessions
use it as true. Thus an incorrect conclusion of one session becomes a "fact" for all
sessions. The skill `memory-lifecycle` gives each record a state, similar to the
short-term and the long-term memory of a person:

| State | Meaning | Index line |
|---|---|---|
| `tentative` | A new record, not verified. Claude uses it as a hint. | `## Tentative` |
| `confirmed` | A verified record. Claude uses it as a fact. | `## Confirmed` |
| `invalid` | A known false or outdated claim. Claude never uses it as a fact. | `invalid/INDEX.md`, or `## Invalid` of the team index |

```
new fact --> tentative --(review: verified, or confirmed by you)--> confirmed
                |                                                       |
                +------------(evidence: false or outdated)------+-------+
                                                                v
                                                             invalid
                                                                |
                tentative <------(new evidence: true again)-----+
```

The states apply to all three roles.

### 10.1 Review

A review makes tentative records confirmed, or moves them to `invalid/`.

- Claude does a review when you ask for it (section 2). If the last review is older than 14
  days, Claude offers one.
- For each record, Claude collects evidence: it reads the cited code, and runs commands
  that only read.
- Claude shows a plan as a table: record, decision, evidence. Claude changes the records
  only after your approval.

A record becomes confirmed when one of these conditions is true:

- Claude verified it against its source (code, configuration, command output).
- You confirmed it.
- Claude saw that it was correct on two or more different days.

A preference or a decision that you state explicitly is confirmed at once.

### 10.2 How Claude finds a record

- At the start of a session, Claude Code loads only `MEMORY.md`, and only its first 200
  lines or 25 KB. It does not load the record files.
- `MEMORY.md` is an index: one short line for each record. Claude reads a record when its
  line shows that the record applies.
- When `MEMORY.md` gets near the limit, Claude Code tells Claude to make it shorter. The
  skill makes groups before that: related records go into a subdirectory with its own
  `INDEX.md`, and `MEMORY.md` keeps one line for the group (`## Groups`).
- Before Claude writes a record, or says that the memory has no information about a
  topic, it searches the memory with Grep. Thus it also finds a record that has no line in
  the loaded index.

The weight of a record comes from its state, not from the position of its line. Claude
sees the section of each line, and uses a confirmed record as a fact and a tentative
record as a hint.

### 10.3 Invalid records

Claude does not delete a record that is not correct. It moves the record to `invalid/`,
writes the reason and the correct fact, and adds an index line. Thus Claude knows the
false claims. If a document, a comment or a person gives such a claim again, Claude tells
you.

`MEMORY.md` has only one line for all invalid personal records: the link to
`invalid/INDEX.md`. Thus the invalid records do not use the space of the index.

### 10.4 Author of a change

Each record has a list of history lines in its frontmatter:

```
- 2026-10-07 alice@laptop created
- 2026-10-09 alice@workstation verified: the build with ninja passed
- 2026-10-21 bob promoted: verified against CMakeLists.txt:12
```

The name comes from `sync.sh user`, the machine from `sync.sh host`. Team records have no
machine names. The git history is the authoritative record of each change: each commit
has the git author of the person.

### 10.5 Files

| File | Content |
|---|---|
| `skills/memory-lifecycle/SKILL.md` | The procedure for Claude: roles, write, review, promote, invalidate. |
| `skills/memory-lifecycle/templates/MEMORY.md` | The personal index with its sections. `sync.sh enable` uses it. |
| `skills/memory-lifecycle/templates/INVALID-INDEX.md` | The index of the invalid personal records. `sync.sh enable` copies it to `invalid/INDEX.md`. |
| `skills/memory-lifecycle/templates/LOCAL-INDEX.md` | The index of the local memory of one machine. |
| `skills/memory-lifecycle/templates/record.md` | A record with all frontmatter fields. |

The skill is a template. Change the rules in your copy, for example the number of days
between two reviews.

An old memory has no sections in `MEMORY.md`. At the first write, Claude adds the
sections and puts the old records into `## Tentative`. At the next review, Claude shows
them to you as one group.

## 11. Conflicts

If two machines or two persons change the same file between two syncs, a rebase
conflict occurs. The SessionStart hook then shows a warning, and Claude tells you. Other
signs:

- `git -C ~/.claude/claude-memory status` shows "rebase in progress".
- Changes from one machine do not arrive on the other machine.

To solve the conflict:

```sh
cd ~/.claude/claude-memory
git status                  # the files in conflict
# edit the files, keep the facts of the two versions
git add <file>
git rebase --continue
git push
```

Each person writes in a different `users/<user>/` directory, and the team memory has no
index file. Thus conflicts between persons occur only when two persons change the same
team record.

## 12. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The personal memory of a project is empty on a different machine | The project is not enabled for you, or `sync.sh user` gives a different name on the two machines. Run `sync.sh status <dir>` on the two machines. Make sure that `git remote get-url origin` gives the same name. |
| `memory` is a real directory, not a symlink | The project is not enabled for you, or the hook did not run (use `/hooks` in Claude Code to see the hooks). Run `sync.sh enable <dir>`. |
| Changes do not get to the server | `ssh -o BatchMode=yes git@git.example.com` fails (key, agent), or a rebase conflict occurred (section 11). |
| A team file is not committed | It contains a forbidden pattern. The SessionStart hook shows the lines. Move the machine detail to the local memory. Check with `sync.sh lint <file>`. |
| A file `<file>.<host>.md` | The script kept two versions (section 4.6). Merge them by hand, then delete the `<host>` file. |
| A session in a subdirectory or a git worktree of a project | Claude Code uses the memory of the main working tree. It is the same memory. |
| The memory of a project is a local directory, and the SessionStart hook says that the project moved | The project is in a repository without a clone on this machine. Run `sync.sh add-repo <alias> <url>`, then start a new session. |
| The SessionStart hook says that a project is in more than one repository | Run `sync.sh repos`. Merge the two `projects/<name>/` directories by hand, and remove one. |
| Claude does not know the local memory | The machine name changed: compare `sync.sh host` with the directories in `users/<user>/hosts/`. Rename the directory, or set `CLAUDE_MEMORY_HOST` (section 4.3). |

## 13. Remove from a machine

1. Replace each symlink with a copy of its memory:

   ```sh
   for m in ~/.claude/projects/*/memory; do
     [ -L "$m" ] && t=$(readlink "$m") && rm "$m" && cp -RL "$t" "$m"
   done
   ```

2. Remove the three hooks from `~/.claude/settings.json`.
3. Remove the import line from `~/.claude/CLAUDE.md`.
4. Remove the symlink `~/.claude/skills/memory-lifecycle` and the file
   `~/.claude/claude-memory-setup`.

You can keep or delete the clone `~/.claude/claude-memory`.

## 14. Instructions for Claude: installation

This section is for Claude Code. It gives the procedure to install the sync on one
machine. The user starts it with the prompt in section 1.

In this section:

- `TEMPLATE` is `https://git.montyho.com/turbyho/claude-memory-sync.git`.
- `MEMORY` is the URL of the memory repository of the user or the team.
- `REPO` is `~/.claude/claude-memory`.

### 14.1 Rules

- Do not push memory to `TEMPLATE` or to a different public remote. If `MEMORY` is equal
  to `TEMPLATE`, stop and tell the user.
- Do not overwrite or delete an existing file or directory. Before you change
  `~/.claude/settings.json` or `~/.claude/CLAUDE.md`, make a backup.
- Do not change `sync.sh`.
- Make each step idempotent. If a step is done already, skip it and tell the user.
- If a step fails, stop. Tell the user the command, the output and the possible cause.

### 14.2 Get the inputs

1. Get `MEMORY` from the prompt. If the prompt does not give it, ask the user.
2. Make sure that the user said that `MEMORY` is a private repository. If not, ask.
3. Get the list of project directories to enable. The list can be empty.

### 14.3 Do a check of the machine

1. Make sure that the system is Linux or macOS (`uname -s`). On native Windows, stop and
   tell the user that the sync does not support it yet.
2. Make sure that `git` 2.31 or later is installed: `git --version`.
3. Make sure that `git config user.email` gives a value. If not, ask the user for the
   email address, and set it with `git config --global user.email`.
4. Make sure that access to `MEMORY` operates without a prompt:

   ```sh
   GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10" git ls-remote MEMORY
   ```

   If the command fails, stop. Tell the user to set up an SSH key or an SSH agent.
5. Make sure that `jq` or `python3` is installed. `sync.sh setup` needs one of them to
   change `~/.claude/settings.json`. If none is installed, stop and tell the user.
6. Look at `REPO`:
   - It does not exist: continue with step 14.4.
   - It is a git clone with `origin` equal to `MEMORY`: skip step 14.4.
   - Other state: stop and ask the user what to do.

### 14.4 Clone the repository

The output of `git ls-remote MEMORY` (step 14.3) tells you which case applies.

If `MEMORY` is empty (no refs), this is the first person. Start from the latest release,
not from the branch `main` of `TEMPLATE`:

```sh
git clone TEMPLATE ~/.claude/claude-memory
cd ~/.claude/claude-memory
git reset -q --hard "$(git tag -l 'v*' --sort=-v:refname | head -n 1)"
git remote rename origin upstream
git remote add origin MEMORY
git push -u origin main
```

If `MEMORY` has a branch `main`, a person installed the sync before:

```sh
git clone MEMORY ~/.claude/claude-memory
git -C ~/.claude/claude-memory remote add upstream TEMPLATE
```

Make sure that `REPO/sync.sh` is executable.

### 14.5 Set up the machine

1. Run:

   ```sh
   ~/.claude/claude-memory/sync.sh setup
   ```

   It adds the hooks to `~/.claude/settings.json` (with a backup), the import line to
   `~/.claude/CLAUDE.md` and the skill symlink. Each step changes nothing if it is done
   already.
2. If the command fails, or shows that it did not change a file because the file is in a
   different state, stop. Tell the user the output. Do not change the file yourself.

### 14.6 Enable the projects

1. Run `~/.claude/claude-memory/sync.sh user`. Tell the user the person name. If the user
   has other machines with the sync, the name must be the same there.
2. Run `~/.claude/claude-memory/sync.sh list`. It shows the projects and the persons that
   use them. Do not enable a project again that is enabled for this person.
3. For each project directory in the list (step 14.2):
   1. Make sure that the directory exists. If not, tell the user and continue with the
      next directory.
   2. Run `~/.claude/claude-memory/sync.sh enable <dir>`.
   3. Look at the project name in the output. If the project has no git remote `origin`,
      tell the user that the name comes from the directory name. The directory must have
      the same name on each machine and for each person.

### 14.7 Do a check of the result

1. Run `~/.claude/claude-memory/sync.sh version`. The machine setup must be equal to the
   needed setup.
2. For each enabled project, run `~/.claude/claude-memory/sync.sh status <dir>`. The
   memory must be a symlink into `REPO/projects/<name>/users/<user>/`.
3. Run `git -C ~/.claude/claude-memory status -sb`. The output must be
   `## main...origin/main` with no changes.
4. Make sure that `~/.claude/skills/memory-lifecycle/SKILL.md` can be read.

### 14.8 Report to the user

Tell the user:

- The changed files and the paths of the backups
- The person name, the machine name, and the enabled projects with their names
- That a new Claude Code session is necessary, because Claude Code loads the hooks at the
  start of a session
- That each person with access to the repository can read all its memory
- What to do on the other machines and for other persons: the prompt of section 1

## 15. Development

The tests run in temporary directories. Each simulated machine has its own `HOME`, thus
the tests do not touch your `~/.claude`. They need `git`, and `jq` or `python3`.

```sh
tests/run.sh
```

| Test | What it tests |
|---|---|
| `tests/test-roles.sh` | Roles, linking, adoption of a local memory, team memory check, disable, slug of a subdirectory and of a worktree |
| `tests/test-update.sh` | Setup (with `jq` and with `python3`), notices, update, conflict at an update |
| `tests/test-repos.sh` | More memory repositories: add-repo, enable --repo, move, relink, local copy |
| `tests/test-migrate.sh` | `tools/migrate.sh`, `tools/validate.sh`, `tools/relink.sh` |

Rules for a change:

- `sync.sh` and the tools are POSIX sh. They must operate on Linux and macOS.
- The text of the files is ASD-STE100 (Simplified Technical English), UTF-8, LF.
- The repository contains no symlinks and no private data (names, paths, host names).
- If you change the setup of a machine, increase `SETUP_VERSION` (section 7.2).
- If you change `sync.sh`, keep section 14 and `UPDATE.md` correct.
- Run `tests/run.sh` before each commit. Add a test for each new function.

## License

MIT. See `LICENSE`.
