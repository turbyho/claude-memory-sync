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
| Shared topic | "Make a shared topic `test-server` for the projects example-app and example-api, and move the facts about the test server into it." |
| Review the memory | "Review the tentative memory records." |
| Confirm a record | "The record about the build with ninja is correct. Promote it." |
| Invalidate a record | "The record about the build with ninja is not correct any more: make works again since commit abc123. Invalidate it." |
| Check a claim | "Is the claim that the API needs a token in the invalid memory records?" |
| Who changed a record | "Show the history of the memory record about the build." |
| History | "Show the changes to the memory of this project in the last week." |
| Merge a conflict file | "Merge the `.<host>.md` files in the memory of this project." |
| Update the script | "Update claude-memory-sync from upstream." |

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
~/.claude/claude-memory/shared/test-server/   <- shared topic (section 9)
```

Git syncs the repository between all machines and all persons.

### 4.1 Repository layout

| Path | Content |
|---|---|
| `projects/<name>/team/` | Team memory of a project (section 5.1). |
| `projects/<name>/users/<user>/` | Personal memory of one person (section 5.2). `MEMORY.md` is the index. |
| `projects/<name>/users/<user>/hosts/<host>/` | Local memory of one machine (section 5.3). |
| `projects/_home/` | Memory of the sessions that start in the home directory. |
| `shared/<topic>/` | Shared topics (section 9). |
| `CLAUDE-MEMORY.md` | Instructions for Claude. You import them into `~/.claude/CLAUDE.md`. |
| `skills/memory-lifecycle/` | Skill for Claude: roles and lifecycle (sections 5 and 10), with templates. |
| `team-memory-check.default` | Forbidden patterns in the team memory (section 5.1). |
| `sync.sh` | Sync script (POSIX sh). The hooks call it. |

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
| `sync.sh list` | Shows the projects and the persons that use them. |

`dir` is the project directory. The default is the current directory.

The team memory of a project is available to all persons, also to a person who did not
enable the project.

### 4.5 Hooks

| Hook | Command | What it does |
|---|---|---|
| `SessionStart` | `sync.sh pull` | Pulls the repository. Links the memory directory of the session if the project is enabled for you. Gives the index of the local memory and of the team memory to Claude. Shows warnings (rebase conflict, team file not committed). |
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
| Symlink to a removed personal memory | You disabled the project on a different machine. Makes a local copy from the git history. |

If a local file is different from the file in the repository, the script keeps the local
version as `<file>.<host>.md` next to the repository version. The old local directory
goes to `~/.claude/memory-backup/<slug>.<time>`. Merge the `<host>` file by hand, or ask
Claude to do it. Then delete the `<host>` file.

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

1. Add the hooks to `~/.claude/settings.json`. If the file has a `hooks` key, merge them
   into it, and keep the hooks that are there:

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

   With `jq`, as one command (it makes a backup first):

   ```sh
   cd ~/.claude && cp settings.json settings.json.bak && jq '
     .hooks.SessionStart += [{"hooks":[{"type":"command","command":"~/.claude/claude-memory/sync.sh pull","timeout":20}]}] |
     .hooks.Stop += [{"hooks":[{"type":"command","command":"~/.claude/claude-memory/sync.sh push","timeout":30,"async":true}]}] |
     .hooks.PreToolUse += [{"matcher":"Write|Edit|MultiEdit","hooks":[{"type":"command","command":"~/.claude/claude-memory/sync.sh check-team","timeout":10}]}]
   ' settings.json.bak > settings.json
   ```

2. Give Claude the instructions. Add this line at the end of `~/.claude/CLAUDE.md`. If the
   file does not exist, make it:

   ```
   @~/.claude/claude-memory/CLAUDE-MEMORY.md
   ```

3. Install the skill `memory-lifecycle` as a symlink. Thus `git pull` updates it:

   ```sh
   mkdir -p ~/.claude/skills
   ln -s ~/.claude/claude-memory/skills/memory-lifecycle ~/.claude/skills/memory-lifecycle
   ```

4. Make sure that the person name is correct. It must be the same on all your machines:

   ```sh
   ~/.claude/claude-memory/sync.sh user
   ```

5. Enable the projects that you want to sync. Do this on one of your machines only:

   ```sh
   ~/.claude/claude-memory/sync.sh enable ~/work/example-app
   ~/.claude/claude-memory/sync.sh enable ~              # memory of the home directory
   ```

   On your other machines, the script links the project at the next session in it.

6. Do a check:

   ```sh
   ~/.claude/claude-memory/sync.sh status ~/work/example-app
   git -C ~/.claude/claude-memory status -sb      # "## main...origin/main", no changes
   ```

   Then start a new Claude Code session in the project and ask: "What is in your memory?"

### 6.4 Other location of the repository

The script finds the repository from its own location. If you clone it to a different
directory, change the path in the hooks, in the import line and in the skill symlink. As
an alternative, set the env var `CLAUDE_MEMORY_REPO`.

## 7. Daily use

Claude reads and writes the memory as usual. The hooks sync it. You do not have to do
more. For the prompts, see section 2.

- Enable a new project: `sync.sh enable <dir>`
- See the history: `git -C ~/.claude/claude-memory log --stat`
- See who changed the team memory: `git -C ~/.claude/claude-memory log --format='%an %ad %s' -- projects/<name>/team`
- Undo a bad memory change: `git -C ~/.claude/claude-memory revert <commit>`. The next
  `push` sends it.
- Sync by hand: `sync.sh pull < /dev/null` and `sync.sh push`.
- Get a new version of the script:

  ```sh
  cd ~/.claude/claude-memory && git pull upstream main && git push
  ```

  The template does not contain files in `projects/` or `shared/`, thus the merge does not
  touch the memory. If you changed the skill `memory-lifecycle` in your copy, the merge can
  cause a conflict in `skills/`. Solve it as in section 11.

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
schema of a database. Write such a fact one time, in `shared/<topic>/`, and put a link to
the topic into each project that uses it. A shared topic is team memory: all persons see
it, and the rules of section 5.1 apply.

1. Make the topic:

   ```sh
   mkdir -p ~/.claude/claude-memory/shared/test-server
   ```

2. Write `shared/test-server/README.md`. Give the rules of the topic and the list of the
   projects that use it.

3. Write the records into `shared/test-server/`. The topic has no index file. Claude
   finds the records with Grep for `^description:`.

4. In `MEMORY.md` of each person and project that uses the topic, add one line in
   `## Groups`:

   ```
   - [Test server](~/.claude/claude-memory/shared/test-server/) - shared: SSH access, database schema
   ```

The repository contains no symlinks. The link is a path in `MEMORY.md`, thus it operates
on each system, also where git cannot make symlinks.

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
4. Remove the symlink `~/.claude/skills/memory-lifecycle`.

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
5. Find which tool can edit JSON: `jq`, else `python3`. If none is available, use your
   file edit tool for step 14.5.
6. Look at `REPO`:
   - It does not exist: continue with step 14.4.
   - It is a git clone with `origin` equal to `MEMORY`: skip step 14.4.
   - Other state: stop and ask the user what to do.

### 14.4 Clone the repository

The output of `git ls-remote MEMORY` (step 14.3) tells you which case applies.

If `MEMORY` is empty (no refs), this is the first person:

```sh
git clone TEMPLATE ~/.claude/claude-memory
cd ~/.claude/claude-memory
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

### 14.5 Add the hooks

1. If `~/.claude/settings.json` does not exist, make it with the content `{}`.
2. Find the hooks that are there already:

   ```sh
   jq '[.. | .command? // empty | select(test("claude-memory/sync.sh"))]' ~/.claude/settings.json
   ```

   If the three commands `sync.sh pull`, `sync.sh push` and `sync.sh check-team` are in
   the output, skip this step. If only some are there, add only the missing hooks.
3. Make a backup: `cp ~/.claude/settings.json ~/.claude/settings.json.bak.<time>`.
4. Add the hooks. Keep all keys and hooks that are there:

   ```sh
   jq '
     .hooks.SessionStart += [{"hooks":[{"type":"command","command":"~/.claude/claude-memory/sync.sh pull","timeout":20}]}] |
     .hooks.Stop += [{"hooks":[{"type":"command","command":"~/.claude/claude-memory/sync.sh push","timeout":30,"async":true}]}] |
     .hooks.PreToolUse += [{"matcher":"Write|Edit|MultiEdit","hooks":[{"type":"command","command":"~/.claude/claude-memory/sync.sh check-team","timeout":10}]}]
   ' ~/.claude/settings.json.bak.<time> > ~/.claude/settings.json
   ```

5. Make sure that the result is valid JSON: `jq empty ~/.claude/settings.json`. If it is
   not valid, restore the backup and stop.

### 14.6 Add the instructions and the skill for Claude

1. If `~/.claude/CLAUDE.md` contains the line `@~/.claude/claude-memory/CLAUDE-MEMORY.md`,
   skip to step 4.
2. If the file exists, make a backup.
3. Add the line at the end of the file. Put an empty line before it. If the file does not
   exist, make it.
4. Look at `~/.claude/skills/memory-lifecycle`:
   - It is a symlink to `REPO/skills/memory-lifecycle`: skip this step.
   - It does not exist: make the symlink:

     ```sh
     mkdir -p ~/.claude/skills
     ln -s ~/.claude/claude-memory/skills/memory-lifecycle ~/.claude/skills/memory-lifecycle
     ```

   - Other state: do not change it. Tell the user.

### 14.7 Enable the projects

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

### 14.8 Do a check of the result

1. For each enabled project, run `~/.claude/claude-memory/sync.sh status <dir>`. The
   memory must be a symlink into `REPO/projects/<name>/users/<user>/`.
2. Run `git -C ~/.claude/claude-memory status -sb`. The output must be
   `## main...origin/main` with no changes.
3. Make sure that `~/.claude/skills/memory-lifecycle/SKILL.md` can be read.

### 14.9 Report to the user

Tell the user:

- The changed files and the paths of the backups
- The person name, the machine name, and the enabled projects with their names
- That a new Claude Code session is necessary, because Claude Code loads the hooks at the
  start of a session
- That each person with access to the repository can read all its memory
- What to do on the other machines and for other persons: the prompt of section 1

## License

MIT. See `LICENSE`.
