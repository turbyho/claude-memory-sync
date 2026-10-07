# claude-memory-sync

Keep the auto memory of Claude Code in git repositories. Use the same memory on all your
machines, and share project knowledge with your team.

- One memory for each project, the same on all your machines (Linux and macOS)
- Three roles of memory: team, personal (one person) and local (one machine)
- Shared topics for facts that more than one project uses
- Different repositories for different projects: for example private and work
- A lifecycle for records: tentative, confirmed, invalid, with a review by Claude
- Automatic updates of the tool
- One POSIX shell script and three Claude Code hooks. The only dependency is `git`.

> WARNING: PUT YOUR MEMORY ONLY INTO PRIVATE REPOSITORIES. EACH PERSON WITH ACCESS TO A
> MEMORY REPOSITORY CAN READ ALL ITS MEMORY, ALSO THE PERSONAL MEMORY OF OTHER PERSONS.

This file is for people. The instructions for Claude are in other files:

| File | For Claude |
|---|---|
| `INSTALL.md` | The installation procedure |
| `UPDATE.md` | The update procedure |
| `CLAUDE-MEMORY.md` | The rules for each session (imported into `~/.claude/CLAUDE.md`) |
| `skills/memory-lifecycle/SKILL.md` | How to write, review and invalidate a record |

Contents:

1. [What it does](#1-what-it-does)
2. [The structure of the memory](#2-the-structure-of-the-memory)
3. [Choose a setup](#3-choose-a-setup)
4. [Installation](#4-installation)
5. [Daily use](#5-daily-use)
6. [Updates](#6-updates)
7. [Problems](#7-problems)
8. [Reference](#8-reference)
9. [Development and releases](#9-development-and-releases)

---

## 1. What it does

### 1.1 The auto memory of Claude Code

While Claude works in a project, it writes notes for later sessions: the build command
that works, a trap in the tests, a decision of the team, your preferences. Claude Code
calls these notes the auto memory. Each note is one Markdown file. An index `MEMORY.md`
has one line for each note. Claude Code loads the index at the start of each session.

Claude Code keeps these notes in `~/.claude/projects/<slug>/memory/`. `<slug>` comes from
the absolute path of the project.

### 1.2 The problems, and the solutions

| Problem of the auto memory | Solution of this tool |
|---|---|
| The memory is on one machine only. On your laptop, Claude does not know what it learned on your workstation. | A git repository that hooks sync at each session. |
| The directory name comes from the path, and the path is different on each machine (`/Users/alice/work/app`, `/home/alice/src/app`). A file sync tool cannot join the two memories. | The project name comes from the git remote of the project, not from the path. |
| Some notes are correct on one machine only, for example the path of a toolchain. | A local memory for each machine. |
| Your colleagues learn the same project traps again. | A team memory for each project. |
| A fact for two projects is written two times, and the copies become different. | Shared topics. |
| Claude writes a conclusion at once, and all later sessions use it as true. | Records start as tentative. A review confirms them, or moves them to the invalid records. |
| There is no history. | Git: each change is a commit with its author. |

---

## 2. The structure of the memory

### 2.1 Overview

All options in one picture. alice has a private main repository and a work repository of
her team:

```
~/.claude/claude-memory/                   MAIN REPOSITORY of alice (git: alice/claude-memory)
│                                          It also holds the tool: sync.sh, skills/, tools/
├── projects/
│   └── home-heating/                      PROJECT (name from the git remote of the project)
│       ├── team/                          TEAM MEMORY: all persons of this repository
│       │   ├── pump-modbus-map.md
│       │   └── invalid/                   known false team records
│       └── users/
│           └── alice/                     PERSONAL MEMORY of alice, on all her machines
│               ├── MEMORY.md              index, loaded at session start
│               ├── build-with-ninja.md
│               ├── invalid/               known false personal records
│               └── hosts/
│                   ├── laptop/            LOCAL MEMORY: only the machine "laptop"
│                   └── workstation/       LOCAL MEMORY: only the machine "workstation"
├── shared/
│   └── test-server/                       TEAM SHARED TOPIC: for more than one project
└── users/
    └── alice/
        ├── repos.conf                     the other repositories of alice
        └── shared/
            └── nas/                       PERSONAL SHARED TOPIC of alice

~/.claude/claude-memory.d/
└── work/                                  PROJECT REPOSITORY "work" (git: team/claude-memory)
    ├── projects/
    │   └── example-app/                   a work project, same structure as above
    │       ├── team/
    │       └── users/alice/ ...
    └── shared/ ...
```

On each machine, the memory directory of Claude Code for a project is a symlink to the
personal memory of the person:

```
~/.claude/projects/-Users-alice-home-heating/memory  ->  ~/.claude/claude-memory/projects/home-heating/users/alice
```

### 2.2 Repositories: main and project repositories

All memory repositories have the same structure, and each one contains the tool. The role
of a repository is different for each person:

| Role for a person | Clone | What it does |
|---|---|---|
| Main repository | `~/.claude/claude-memory` | The hooks run its `sync.sh`. New projects go into it. Its `users/<user>/repos.conf` lists the other repositories of the person. |
| Project repository | `~/.claude/claude-memory.d/<alias>/` | Holds the memory of some projects. You give it a short name, the alias. |

Each project is in one repository. One repository can be the main repository of one
person and a project repository of an other person:

| Repository | alice | bob |
|---|---|---|
| `alice/claude-memory` (private) | main | - |
| `team/claude-memory` (team) | project repository `work` | main |

### 2.3 Roles of a record

| Role | Location | Who uses it | Loaded at session start | Rules |
|---|---|---|---|---|
| Team | `projects/<name>/team/` | All persons of the repository | An index that the hook makes from the records | No absolute paths, no machine names, no links outside the project. A hook blocks such a write. Claude writes only after your approval. |
| Personal | `projects/<name>/users/<user>/` | One person, on all machines of the person | `MEMORY.md` | Facts about you and the project that are correct on all your machines |
| Local | `projects/<name>/users/<user>/hosts/<host>/` | One person, on one machine | `hosts/<host>/INDEX.md` | Paths, devices, settings of one machine |

Claude selects the role:

1. A record with an absolute path, a home directory path, a device, or a setting of the
   machine is **local**.
2. A record about you (preference, work method, decision, correction) is **personal**.
3. For a fact about the project that can be correct for all persons, Claude asks you:
   **team or personal?**
4. All other records are personal.

### 2.4 Shared topics

A fact that more than one project uses goes into a shared topic, not into each project.

| Type | Location | For | Check of the team rules |
|---|---|---|---|
| Team shared topic | `shared/<topic>/` | Facts that are correct for all persons, for example the access to a test server | Yes |
| Personal shared topic | `users/<user>/shared/<topic>/` | Your facts for some of your projects, for example the access to your NAS | No |

- A shared topic links only projects of the same repository.
- `MEMORY.md` of each project that uses the topic has one line for the topic in
  `## Groups`.
- Claude proposes a new topic, and makes it only after your approval.

### 2.5 States of a record

| State | Meaning | Index |
|---|---|---|
| `tentative` | New, not verified. Claude uses it as a hint. | `## Tentative` in `MEMORY.md` |
| `confirmed` | Verified. Claude uses it as a fact. | `## Confirmed` in `MEMORY.md` |
| `invalid` | A known false or outdated claim. Claude never uses it as a fact, and tells you if somebody gives it again. | `invalid/INDEX.md` |

```
new fact --> tentative --(review: verified, or confirmed by you)--> confirmed
                |                                                       |
                +------------(evidence: false or outdated)------+-------+
                                                                v
                                                             invalid
```

- A preference or a decision that you state is confirmed at once.
- A review: Claude collects evidence for each tentative record, shows a plan as a table,
  and changes the records only after your approval. Claude offers a review if the line
  `Last review:` of `MEMORY.md` is `never` or older than 14 days.
- Each record has history lines: date, person, machine, action.

### 2.6 Names

| Name | Source | Command |
|---|---|---|
| Project | The name of the git remote `origin` of the project (`git@...:team/example-app.git` gives `example-app`). Without a remote: the directory name. The home directory: `_home`. | `sync.sh status` |
| Person | The part before `@` of `git config user.email` in the main repository. Env var `CLAUDE_MEMORY_USER` overrides it. It must be the same on all your machines. | `sync.sh user` |
| Machine | `scutil --get LocalHostName` on macOS, `hostname -s` on Linux. Env var `CLAUDE_MEMORY_HOST` overrides it. | `sync.sh host` |

A session in a subdirectory or in a git worktree of a project uses the memory of the
project.

---

## 3. Choose a setup

| Setup | Repositories | For whom |
|---|---|---|
| A. One person | One private main repository | You want the same memory on all your machines. |
| B. One person, private and work separated | Private main repository, and a work repository as project repository | You do not want work memory in your private repository, or the reverse. |
| C. Team, members with a private repository | Each member: private main repository. The team repository is a project repository of each member. | Members also have private projects. |
| D. Team, members without a private repository | Each member uses the team repository as main repository. | Members only have team projects. |

You can change the setup later:

- Add a repository: `sync.sh add-repo`.
- Move a project to a different repository: `sync.sh move`.

---

## 4. Installation

### 4.1 Requirements

- Linux or macOS. Native Windows is not supported yet. In WSL, use the Linux procedure
  (not tested).
- `git` 2.31 or later, with `user.email` set
- SSH access to your git server without a password prompt (a key without a passphrase,
  or an SSH agent). The hooks cannot ask for a password.
- `jq` or `python3`

### 4.2 Install with Claude (recommended)

1. On your git server, make the PRIVATE repositories that your setup needs (section 3).
   An empty repository is sufficient. A team repository must exist only one time.
2. Start Claude Code in your home directory, and give it one of these prompts. Change the
   URLs and the directories.

**The first machine, a new main repository:**

```text
Install claude-memory-sync from https://git.montyho.com/turbyho/claude-memory-sync.
Clone it to a temporary directory, read its INSTALL.md, and do the procedure.

My main memory repository is git@git.example.com:alice/claude-memory.git.
It is a private repository.
Enable the memory for these projects: ~/work/example-app, ~/home-heating.
```

**An other machine of the same person:** the same prompt, without the list of projects.
Your projects are enabled already.

**With a team repository as project repository (setup B or C):** add to the prompt:

```text
Then add git@git.example.com:team/claude-memory.git as the project repository "work",
and enable these projects in it: ~/work/example-app.
```

**A team member who uses the team repository as main repository (setup D):** give the
team repository as the main memory repository in the first prompt.

3. Read the report of Claude: the changed files, the backups, the person and machine
   names, the enabled projects.
4. Start a new Claude Code session. Claude Code loads the hooks only at the start of a
   session.

### 4.3 Install by hand

1. Clone the main repository:
   - A new, empty main repository: clone this tool, start from its latest release, and
     push it:

     ```sh
     git clone https://git.montyho.com/turbyho/claude-memory-sync.git ~/.claude/claude-memory
     cd ~/.claude/claude-memory
     git reset -q --hard "$(git tag -l 'v*' --sort=-v:refname | head -n 1)"
     git remote rename origin upstream
     git remote add origin git@git.example.com:alice/claude-memory.git
     git push -u origin main
     ```

   - An existing main repository:

     ```sh
     git clone git@git.example.com:alice/claude-memory.git ~/.claude/claude-memory
     git -C ~/.claude/claude-memory remote add upstream https://git.montyho.com/turbyho/claude-memory-sync.git
     ```

2. Set up the machine:

   ```sh
   ~/.claude/claude-memory/sync.sh setup
   ```

   It adds the three hooks to `~/.claude/settings.json` (with a backup), the import line
   of `CLAUDE-MEMORY.md` to `~/.claude/CLAUDE.md`, and the symlink of the skill. Each step
   changes nothing if it is done already.
3. Make sure that the person name is correct: `~/.claude/claude-memory/sync.sh user`.
4. Enable your projects (one time, on one of your machines), and add your project
   repositories (section 4.4).
5. Do a check: `sync.sh version`, `sync.sh list`, `sync.sh status <dir>`. Then start a new
   Claude Code session.

### 4.4 Enable projects, add repositories

| Task | Command |
|---|---|
| Enable a project in the main repository | `sync.sh enable ~/work/example-app` |
| Enable the memory of the home directory | `sync.sh enable ~` |
| Add a project repository | `sync.sh add-repo work git@git.example.com:team/claude-memory.git` |
| Enable a project in a project repository | `sync.sh enable ~/work/example-app --repo work` |

`sync.sh` is `~/.claude/claude-memory/sync.sh`. An enabled project and an added
repository go to all your machines: they link and clone them at their next session.

---

## 5. Daily use

### 5.1 What happens automatically

| When | What |
|---|---|
| Start of a session | `sync.sh pull`: pulls all repositories, clones the missing ones, links the memory of the project, and gives Claude the local and the team index. It also shows warnings and notices (conflict, new release, setup). |
| Each write into the team memory | `sync.sh check-team` blocks absolute paths, home directory paths and links outside the project. |
| After each reply of Claude | `sync.sh push`: commits and pushes all changes. |

You do not have to do more. Claude reads and writes the memory as usual.

### 5.2 Prompts

You can give these prompts in any language:

| Task | Prompt |
|---|---|
| Save a fact | "Remember: the build needs ninja." |
| Save for this machine | "Remember for this machine: the debug probe is on /dev/ttyACM0." |
| Team memory | "Save to the team memory: the integration tests need the docker service." |
| Show the memory | "What is in your memory about this project, and where does it come from?" |
| Review | "Review the tentative memory records." |
| Confirm a record | "The record about the build with ninja is correct. Promote it." |
| Invalidate a record | "The record about the build with ninja is not correct any more: make works again. Invalidate it." |
| Check a claim | "Is the claim that the API needs a token in the invalid memory records?" |
| Shared topic | "Make a personal shared topic `nas` for my projects that use the NAS, and move the NAS records into it." |
| Enable a project | "Enable the memory for this project." |
| Other repository | "Add the memory repository `work` (git@git.example.com:team/claude-memory.git), and move this project to it." |
| Renamed repository | "The repository `work` is now git@git.example.com:team/memory.git. Rename the alias to `team`." |
| History | "Show the changes to the memory of this project in the last week." |
| Update the tool | "Update claude-memory-sync." |

### 5.3 Commands

All commands are in `~/.claude/claude-memory/sync.sh`. `[dir]` is a project directory.
The default is the current directory.

| Command | What it does |
|---|---|
| `status [dir]` | Shows the project, its repository, the person, the machine and the memory link. |
| `list` | Shows all projects, their repository and their persons. |
| `repos` | Shows all repositories and their projects. |
| `enable [dir] [--repo <alias>]` | Enables the personal memory of the project for you, in the main or in a project repository. |
| `disable [dir]` | Disables your personal memory of the project, on all your machines. The memory stays as a local copy. The team memory and other persons do not change. |
| `move [dir] <alias>` | Moves the project (team memory and all persons) to an other repository. `main` is the main repository. |
| `add-repo <alias> <url>` | Adds a project repository. It puts the tool into the repository if it has none. |
| `rename-repo <old> <new> [<url>]` | Renames the alias, and sets a new URL (for example after a rename on the git server). |
| `user`, `host` | Show the person name and the machine name. |
| `version` | Shows the versions of the tool and of the setup of the machine. |
| `setup` | Sets up the machine (hooks, instructions, skill). |
| `update` | Updates the tool (section 6). |
| `lint <file>...` | Shows forbidden patterns in team memory files. |

### 5.4 Who can read what

Each person with access to a repository can read all its memory: the team memory, and the
personal and local memory of all persons in it. Do not write private information into the
memory. For private projects, use a private repository (setup B or C).

---

## 6. Updates

### 6.1 How you get a new release

1. One time in 24 hours, `sync.sh pull` looks for a new release in `upstream`.
2. If there is one, Claude tells you, reads `UPDATE.md` of the new release, and does the
   update: `sync.sh update` merges the release into your main repository and into your
   project repositories, pushes, and sets up the machine.
3. Your other machines get the new release with their next `pull`. If a release changes
   the setup of a machine, Claude runs `sync.sh setup` there.

To update at once, say "Update claude-memory-sync." or run `sync.sh update`.

The tool files and the memory files are in different directories. Thus an update does not
touch the memory. If you changed a file of the tool (for example the skill), an update can
cause a conflict. Then `sync.sh update` stops and changes nothing, and Claude asks you how
to merge.

> CAUTION: AN UPDATE RUNS NEW CODE FROM `upstream` ON ALL YOUR MACHINES. SET `upstream`
> ONLY TO A REPOSITORY THAT YOU TRUST.

---

## 7. Problems

### 7.1 Conflicts

If two machines or two persons change the same file between two syncs, a rebase conflict
occurs. The start of the next session shows a warning, and Claude tells you. To solve it:

```sh
cd ~/.claude/claude-memory          # or the clone of the project repository
git status                          # the files in conflict
# edit the files, keep the facts of the two versions
git add <file>
git rebase --continue
git push
```

Each person writes into an own `users/<user>/`, and the team memory has no index file.
Thus conflicts between persons occur only when two persons change the same team record.

### 7.2 Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The memory of a project is empty on an other machine | The project is not enabled for you, or `sync.sh user` gives a different name there. Compare `sync.sh status <dir>` on the two machines. |
| `memory` is a real directory, not a symlink | The project is not enabled, or the hook did not run (`/hooks` in Claude Code shows the hooks). Run `sync.sh enable <dir>`. |
| Changes do not get to the server | SSH without a prompt fails (key, agent), or a conflict occurred (section 7.1). |
| A team file is not committed | It contains a forbidden pattern. The start of the session shows the lines. Move the machine detail to the local memory. |
| A file `<file>.<host>.md` | The sync found two different versions of a file. Merge them, then delete the `<host>` file. |
| A project is in more than one repository | `sync.sh repos` shows them. Merge the two `projects/<name>/` by hand, and remove one. |
| A repository was renamed on the git server | `sync.sh rename-repo <alias> <alias> <new url>`. Each person who uses it does this one time. |
| Claude does not know the local memory | The machine name changed: compare `sync.sh host` with `users/<user>/hosts/`. Rename the directory, or set `CLAUDE_MEMORY_HOST`. |

### 7.3 Remove from a machine

1. Replace each memory symlink with a copy:

   ```sh
   for m in ~/.claude/projects/*/memory; do
     [ -L "$m" ] && t=$(readlink "$m") && rm "$m" && cp -RL "$t" "$m"
   done
   ```

2. Remove the three `sync.sh` hooks from `~/.claude/settings.json`.
3. Remove the import line from `~/.claude/CLAUDE.md`.
4. Remove `~/.claude/skills/memory-lifecycle` and `~/.claude/claude-memory-setup`.
5. You can keep or delete `~/.claude/claude-memory` and `~/.claude/claude-memory.d`.

---

## 8. Reference

### 8.1 Files of the tool

| Path | Content |
|---|---|
| `sync.sh` | The sync script (POSIX sh). The hooks call it. |
| `CLAUDE-MEMORY.md` | Rules for Claude in each session. |
| `INSTALL.md`, `UPDATE.md` | Procedures for Claude: installation, update. |
| `skills/memory-lifecycle/` | Skill for Claude, with templates of `MEMORY.md`, the local index, the invalid index and a record. |
| `team-memory-check.default` | Forbidden patterns of the team memory. To change them for a repository, copy the file to `.memory-check` in the root of the repository. |
| `VERSION`, `CHANGELOG.md` | Version and changes of the tool. |
| `tools/validate.sh <repo>` | Check of a memory repository: index links, index lines, frontmatter, team rules. |
| `tests/` | Automatic tests (section 9). |
| `users/<user>/repos.conf` | The project repositories of a person: one line `<alias> <url>`. |
| `users/<user>/repos.renamed` | Renamed aliases, for the other machines of the person. |

Outside the repository: `~/.claude/claude-memory-setup` (the setup version of the
machine), `~/.claude/memory-backup/` (local memory directories before their first link).

### 8.2 Hooks

| Hook | Command | Timeout |
|---|---|---|
| `SessionStart` | `~/.claude/claude-memory/sync.sh pull` | 20 s |
| `Stop` (async) | `~/.claude/claude-memory/sync.sh push` | 30 s |
| `PreToolUse` (`Write`, `Edit`, `MultiEdit`) | `~/.claude/claude-memory/sync.sh check-team` | 10 s |

The hooks are global, but they change nothing in a project that is in no repository. The
script ignores network errors: without the server, Claude uses the local copy, and the
next `push` sends the changes.

### 8.3 Linking of a session

| State of `~/.claude/projects/<slug>/memory` | What `sync.sh pull` does |
|---|---|
| Symlink to the personal memory | Nothing |
| Does not exist | Makes the symlink |
| Real directory | Copies its files into the personal memory, moves the directory to `~/.claude/memory-backup/`, then makes the symlink. A file that is different in the two places is kept as `<file>.<host>.md`. |
| Symlink to a removed place, project now in an other repository | Makes the symlink to the new place |
| Symlink to a removed place, project in no repository of this machine | Makes a local copy from the git history, and tells Claude why |

### 8.4 How Claude finds a record

- At the start of a session, Claude Code loads only the first 200 lines or 25 KB of
  `MEMORY.md`, and no record file. It removes HTML comments from `MEMORY.md`.
- `MEMORY.md` is an index: one short line for each record. Claude reads a record when its
  line applies.
- When `MEMORY.md` gets long, Claude makes groups: a subdirectory with an own `INDEX.md`,
  and one line in `## Groups`.
- Before Claude writes a record, or says that the memory has no information, it searches
  the memory with Grep.

### 8.5 Record format

```markdown
---
name: build-with-ninja
description: The build needs ninja (cmake -G Ninja)
metadata:
  type: project                 # user | feedback | project | reference
  status: confirmed             # tentative | confirmed | invalid
  role: personal                # team | personal | local
  source: code                  # user | code | command | docs | session
  evidence: CMakeLists.txt:12
  history:
    - 2026-10-07 alice@laptop created
    - 2026-10-21 alice@workstation promoted: verified against CMakeLists.txt:12
---
The fact.
```

---

## 9. Development and releases

### 9.1 Tests

```sh
tests/run.sh
```

The tests run in temporary directories. Each simulated machine has its own `HOME`, thus
the tests do not touch your `~/.claude`.

| Test | What it tests |
|---|---|
| `tests/test-roles.sh` | Roles, linking, adoption of a local memory, team memory check, disable, slug, default directory |
| `tests/test-update.sh` | Setup (with `jq` and `python3`), notices, update, conflict |
| `tests/test-repos.sh` | Project repositories: add-repo, enable --repo, move, rename-repo |
| `tests/test-shared-main.sh` | One repository as main repository and project repository; update of all copies of the tool |
| `tests/test-validate.sh` | `tools/validate.sh` |
| `tests/test-release.sh` | `VERSION`, `CHANGELOG.md`, `UPDATE.md` and the latest tag agree |

### 9.2 Rules for a change

- `sync.sh` and the tools are POSIX sh, for Linux and macOS.
- The text of the files is ASD-STE100 (Simplified Technical English), UTF-8, LF.
- No symlinks and no private data (names, paths, host names) in the repository.
- If you change the setup of a machine, increase `SETUP_VERSION` in `sync.sh`.
- If you change `sync.sh`, keep `INSTALL.md` and `UPDATE.md` correct.
- Add a test for each new function. Run `tests/run.sh` before each commit.

### 9.3 Publish a release

1. Write the changes into `CHANGELOG.md`, in a new section `## vX.Y.Z - <date>`. Write
   them for the user: what is new, what is different, what the user must do.
2. Write the new version into `VERSION`.
3. Add a section `### vX.Y.Z` to `UPDATE.md`, "Steps for each release". If the update
   needs more steps (for example a change of the memory layout), write them there.
4. Run `tests/run.sh`.
5. Commit, tag and push. Do not change a tag after the push: if a release is wrong,
   publish a new release.

   ```sh
   git commit -am "Release vX.Y.Z"
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The memory repositories find the release within 24 hours.

## License

MIT. See `LICENSE`.
