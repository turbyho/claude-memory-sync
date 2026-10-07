---
name: memory-lifecycle
description: Use when you write, review, promote or invalidate a record in the synced Claude memory (claude-memory-sync), or select its role (team, personal, local). Triggers - a new fact to save, a request to review the memory, a tentative record to confirm, a record that is false or outdated, a claim to compare with the known invalid records, a MEMORY.md that is near its size limit, a team memory record. Applies when the memory directory of the session is a symlink into ~/.claude/claude-memory or ~/.claude/claude-memory.d, or when the SessionStart hook gave a team memory.
---

# Memory lifecycle

Each memory record has a role and a state. The role tells who uses the record: the team,
one person, or one machine. The state tells how much Claude can trust the record. A new
record starts as `tentative`. A review makes it `confirmed`, or moves it to `invalid`.
Claude keeps the invalid records, because a false claim that Claude knows is false does
not come back.

> This skill is a template. Change the rules in your copy of claude-memory-sync. The
> rules are a draft and can change.

## 1. How Claude Code loads the memory

- At the start of a session, Claude Code loads only `MEMORY.md`, and only its first 200
  lines or 25 KB. When `MEMORY.md` is near the limit, Claude Code tells you to make it
  shorter.
- Claude Code does not load the record files. You read a record with the file tools when
  its index line shows that it applies.
- A record that has no line in the loaded index is not known to you. To find it, search
  the memory directory with Grep.

Thus `MEMORY.md` is an index, not the content. Each line is one record or one group.

## 2. States

| State | Location | Index | How to use the record |
|---|---|---|---|
| `tentative` | `<memory>/` or `<memory>/<group>/` | `## Tentative` | A hint. Before a risky action that depends on it, verify it. |
| `confirmed` | `<memory>/` or `<memory>/<group>/` | `## Confirmed` | A fact. If the code or the user contradicts it, invalidate it (section 8). |
| `invalid` | `<memory>/invalid/` | `invalid/INDEX.md` | Never a fact. Use it to recognize a known false or outdated claim. |

`<memory>` is the memory directory of the session. A record without `metadata.status` is
`tentative`.

The weight of a record comes from its state, not from the position of its line. A
confirmed record is a fact. A tentative record is a hint.

## 3. Roles

A memory repository has three roles of memory for each project:

| Role | Location | Who uses it |
|---|---|---|
| `team` | `<repo>/projects/<name>/team/` | All persons that use the repository |
| `personal` | `<memory>/` (`<repo>/projects/<name>/users/<user>/`) | One person, on all machines of the person |
| `local` | `<memory>/hosts/<host>/` | One person, on one machine |

- `<repo>` is the memory repository of the project: the main repository
  `~/.claude/claude-memory`, or `~/.claude/claude-memory.d/<alias>/`. Each project is in
  one repository. `~/.claude/claude-memory/sync.sh status` shows it, and the SessionStart
  hook gives the full paths.
- `<user>` is the output of `~/.claude/claude-memory/sync.sh user`.
- `<host>` is the output of `~/.claude/claude-memory/sync.sh host`. Do not use
  `hostname` directly, because on macOS its value can change with the network.
- All persons with access to the repository can read all roles, also the personal memory
  of other persons. Do not write private information into the memory.

### 3.1 Select the role

Use these rules in this sequence. Stop at the first rule that applies.

1. **`local`**: the record contains one of these:
   - An absolute path, or a path in the home directory (`/home/...`, `/Users/...`,
     `~/...`, `C:\...`)
   - A link to a file outside the project
   - A device name or a port (`/dev/ttyUSB0`, `COM3`, a USB serial number)
   - The installed version or location of a tool on this machine
   - A mount point, a local service, or a setting of this machine
2. **`personal`**: the record is about the user: a preference, a work method, a decision
   of the user, a correction of your work.
3. **Ask the user**: the record is a fact about the project (code, build, tests,
   conventions, architecture) that can be correct for all persons, and the project has a
   team memory (the SessionStart hook showed "Team memory of this project"). Ask: "Team
   memory or personal memory?" Write it only after the answer.
4. **`personal`**: all other records.

Do not ask about the role of a `local` or a `personal` record.

If a fact has a general part and a machine part, write two records: the general fact as
`team` or `personal`, the machine detail as `local`. Link them with `[[name]]`.

### 3.2 Select the place: project or shared topic

After the role, select the place of a `team` or `personal` record:

| The fact applies to | Role `personal` | Role `team` |
|---|---|---|
| One project | `<memory>/` | `<repo>/projects/<name>/team/` |
| More than one project | Personal shared topic `<repo>/users/<user>/shared/<topic>/` | Team shared topic `<repo>/shared/<topic>/` |

1. If the fact applies to more than one project, look at the shared topics of its role.
   The `## Groups` section of `MEMORY.md` links to them. Also run `ls` on
   `<repo>/shared/` and `<repo>/users/<user>/shared/`. A shared topic can only link
   projects of the same repository.
2. If a topic covers the fact, write the record into that topic (section 6).
3. If no topic covers the fact, propose a new topic to the user: its name, its role and
   the projects that use it. Make it only after the approval (section 11.1). If the user
   does not approve, write the record into the project.

A `local` record always stays in the project: `<memory>/hosts/<host>/`. There are no
local shared topics.

### 3.3 Local memory

- The hook `SessionStart` puts the first 100 lines of `hosts/<host>/INDEX.md` into your
  context. Thus a local record does not need a line in `MEMORY.md`.
- `hosts/<host>/INDEX.md` has the sections `## Confirmed`, `## Tentative` and
  `## Invalid`. Use `templates/LOCAL-INDEX.md` for a new file.
- The lifecycle (sections 6 to 9) is the same. Invalid local records go to
  `hosts/<host>/invalid/`, with their line in `## Invalid` of the local index.
- Use only the directory of this machine. Do not read or change `hosts/` of a different
  machine, except when the user asks.
- Git syncs the local memory as a backup, but only this machine uses it.

## 4. Record format

Use `templates/record.md` of this skill. The frontmatter has these fields:

```markdown
---
name: build-needs-ninja
description: The build fails with make; use ninja (cmake -G Ninja)
metadata:
  type: project                 # user | feedback | project | reference
  status: tentative             # tentative | confirmed | invalid
  role: personal                # team | personal | local
  created: 2026-10-07
  source: code                  # user | code | command | docs | session
  evidence: CMakeLists.txt:12 requires the Ninja generator
  history:
    - 2026-10-07 alice@laptop created
---
```

Fields for an invalid record, in addition:

```markdown
  invalidated: 2026-10-20
  reason: outdated              # false | outdated
  superseded_by: build-uses-make
```

Claude Code adds the field `modified` itself. Do not write it.

### 4.1 Author of a change

Each change of a record adds one line to `metadata.history`:

```
<date> <user>@<host> <action>[: <detail>]      personal and local records
<date> <user> <action>[: <detail>]             team records (no machine names)
```

- `<user>`: the output of `~/.claude/claude-memory/sync.sh user`
- `<host>`: the output of `~/.claude/claude-memory/sync.sh host`
- `<action>`: `created`, `edited`, `verified`, `promoted`, `merged`, `invalidated` or
  `restored`

The git history is the authoritative record of each change. The `history` lines are a
summary that Claude can read without git.

## 5. Find a record

Before you write a new record, and before you tell the user that the memory has no
information about a topic:

1. Read the applicable lines of `MEMORY.md`, the `INDEX.md` of each applicable group, and
   the team memory index that the SessionStart hook gave.
2. Search with Grep for the key words of the topic in:
   - The memory directory, with its subdirectories (groups, `hosts/<host>/`, `invalid/`)
   - The team memory of the project, with `team/invalid/`
   - The shared topics that `## Groups` links to

## 6. Write a new record

1. Find the existing records (section 5). If a record covers the topic, update that
   record (step 7). Do not make a duplicate.
2. Read `invalid/INDEX.md`, `## Invalid` of the local index, and the invalid team
   records. If the new fact is equal to an invalid claim, do not write it. Tell the user
   that the memory has this claim as invalid, and give the reason.
3. Select the role (section 3.1) and the place (section 3.2).
4. Write the record from `templates/record.md` into the place:
   - `status: tentative`
   - `role`
   - `source` and `evidence`: where the fact comes from. Give `path:line`, a command, or
     a quote of the user.
   - One history line `created`
5. Exception: if the user explicitly states a preference or a decision of their own (type
   `user` or `feedback`), use `status: confirmed`. The user is the authority for these
   facts.
6. Add the index line:
   - `personal`: in the applicable section of `MEMORY.md`, or in the `INDEX.md` of the
     applicable group
   - `local`: in `hosts/<host>/INDEX.md`. If the file does not exist, make it from
     `templates/LOCAL-INDEX.md`.
   - `team`: none. The team memory has no index file (section 12).
   - Shared topic: the topic has no index file. Make sure that `## Groups` of
     `MEMORY.md` has the line of the topic, and that its key words cover the new record.
     If the topic has lines for each record, add one (section 11).
7. To update an existing record, change its text and add a history line `edited`. If the
   change contradicts the old text of a confirmed record, use section 8.

## 7. Review the tentative records

Do a review when:

- The user asks for it.
- The section `## Tentative` has more than 10 lines.
- The date in the line `Last review: <date>` of `MEMORY.md` is older than 14 days, or the
  line is `Last review: never`, and there are tentative records. In this case, offer the
  review to the user. Do not start it without approval. If the user declines, do not
  offer it again in the same session.

### 7.1 Procedure

1. For each tentative record, collect the evidence:
   - Read the files and the `path:line` that the record cites.
   - Run only commands that read. Do not run a command that changes a state.
   - Read the history lines.
2. Select one decision for each record (section 7.2).
3. Show the plan to the user as a table: record, decision, evidence. Wait for the approval.
4. Do the approved decisions:
   - Change `status`, add a history line, and move the index line to its new section.
   - For an invalidation, use section 8.
5. Set the line `Last review: <date>` in `MEMORY.md` to the date of today.
6. Report what you changed.

### 7.2 Decisions

| Decision | Condition | Action |
|---|---|---|
| Promote | One of the criteria A, B or C is true, and no blocker applies. | `status: confirmed`, history line `promoted: <criterion and evidence>`. |
| Merge | A confirmed record covers the same topic. | Add the fact to the confirmed record, delete the tentative record, add the history line `merged` to the confirmed record. |
| Keep | There is no evidence for it and no evidence against it. | No change. If the record is older than 30 days, ask the user: promote or delete. |
| Invalidate | Evidence shows that the claim is false or outdated, and the claim can come back. | Section 8. |
| Delete | The record is a duplicate, is about work that is finished, or has no use. | Delete the file and its index line. |

Criteria for a promotion:

- **A. Verified now.** You verified the claim against its source of truth in this review:
  code, configuration, command output. Give the evidence.
- **B. Confirmed by the user.** The user confirmed the claim. Quote the user.
- **C. Verified in use.** The record has two or more history lines `verified` from
  different days.

Blockers. Do not promote a record when one of these applies:

- It contains a credential value.
- It describes a temporary state (a running job, a branch in progress, a bug that is
  not fixed yet).
- It is correct on one machine only, but it is not in the local memory (section 3.1).

### 7.3 Verification in use

When you use a record in your work and you see that it is correct, add a history line:

```
2026-10-09 alice@workstation verified: the build with ninja passed
```

Add a maximum of one `verified` line for each record for each day. These lines are
criterion C of a promotion. When you see that a record is not correct, use section 8 at
once and tell the user.

## 8. Invalidate a record

Use this section when evidence shows that a tentative or a confirmed record is false or
outdated:

- `false`: the claim was never true (an incorrect assumption or conclusion).
- `outdated`: the claim was true, but the system changed.

To invalidate a confirmed record, you must have evidence from the source of truth, or a
statement of the user. An assumption is not sufficient.

1. Do not delete the record. Move it to `<memory>/invalid/<file>.md`.
2. In the frontmatter, set `status: invalid`, `invalidated`, `reason` and `evidence`. Add
   the history line `invalidated: <short reason>`.
3. At the start of the body, add this line:

   ```
   INVALID: <the claim> is not true. Correct: <the correct fact, or "unknown">.
   ```

4. If you know the correct fact, write a new record for it (section 6). If you verified it
   now, use `status: confirmed`. Set `superseded_by` in the invalid record.
5. Remove the old index line. Add a line to `invalid/INDEX.md`:

   ```
   - [Build needs ninja](build-needs-ninja.md) - NOT TRUE since 2026-10: make works again, see [[build-uses-make]]
   ```

6. Find the links `[[<name>]]` to the record in the other records. Change them to the new
   record, or remove them.
7. Tell the user what you invalidated, and why.

## 9. Use the invalid records

- `MEMORY.md` has only one line for the invalid records: a link to `invalid/INDEX.md`.
  Thus the invalid records do not use the space of the index.
- Read `invalid/INDEX.md` before you write a record (section 6), and when a claim seems
  doubtful to you.
- If the code, a document or the user gives a claim that is in `invalid/INDEX.md`, tell
  the user. Cite the invalid record.
- If new evidence shows that an invalid claim is true again, move the record back, set
  `status: tentative`, and add the history line `restored: <evidence>`.
- Do not delete an invalid record without the approval of the user.

## 10. The index MEMORY.md

Use `templates/MEMORY.md` of this skill. It has these sections:

| Section | Content |
|---|---|
| `## Confirmed` | One line for each confirmed record that is not in a group |
| `## Tentative` | One line for each tentative record that is not in a group |
| `## Groups` | One line for each group and each shared topic: a link to its `INDEX.md` and the key words of its records |
| `## Invalid` | One line: the link to `invalid/INDEX.md` |

Rules:

- Keep each line short: a link, a dash, and one line of description. The description
  tells you if the record applies, thus it must contain the key words.
- Do not put information for Claude into an HTML comment (`<!-- ... -->`) in
  `MEMORY.md`. Claude Code removes these comments before it loads the file, thus you do
  not see them at the start of a session.
- If `MEMORY.md` is longer than 150 lines, make groups (section 10.1). Do not wait for the
  limit of Claude Code.
- If `MEMORY.md` has no sections (an old memory), add them. Put the existing lines into
  `## Tentative`. At the next review, show these records to the user as one group.

### 10.1 Groups

A group is a subdirectory with related records and its own index:

```
<memory>/build/INDEX.md          # one line for each record of the group, with its state
<memory>/build/ninja-setup.md
<memory>/build/ci-cache.md
```

1. Select records with one subject (for example, the build, the deployment, the test
   server). Use 5 or more records for a group.
2. Move the records into `<memory>/<group>/`. Their names do not change, thus the links
   `[[name]]` stay correct.
3. Write `<group>/INDEX.md` with the sections `## Confirmed` and `## Tentative`.
4. In `MEMORY.md`, replace the lines of these records with one line in `## Groups`:

   ```
   - [Build](build/INDEX.md) - ninja, cmake presets, CI cache, cross-compile toolchain
   ```

## 11. Shared topics

A shared topic holds facts that more than one project uses, for example the access to a
test server. There are two types:

| Type | Location | Rules |
|---|---|---|
| Team shared topic | `<repo>/shared/<topic>/` | Team memory: section 12 applies, the PreToolUse hook checks it. |
| Personal shared topic | `<repo>/users/<user>/shared/<topic>/` | Personal memory of one person, for more than one project of the person. No check of patterns. |

Use a personal shared topic for the facts of one person (for example, the access of the
user to a home server, with paths of the user). Use a team shared topic for facts that
are correct for all persons.

The two types have the same structure:

- `<topic>/README.md` gives the rules of the topic and the list of the projects that use
  it.
- The topic has no index file. To see its records, search with Grep for `^description:`
  in the topic directory.
- Its invalid records go to `<topic>/invalid/`.
- Do not make a symlink to a shared topic. The repository contains no symlinks, because
  git cannot make them on all systems.

Index lines in `MEMORY.md` of each project that uses the topic:

- **Topic line (necessary).** One line in `## Groups`: the link to the topic directory,
  and the key words of all its records. You find a record of the topic through these key
  words, thus keep them complete.
- **Record lines (optional).** Below the topic line, one indented line for each record.
  Use them for a small topic (10 records or less), where they help you to find a record.
  If a topic has record lines, they must list all its records. When you add, remove or
  invalidate a record of the topic, change the record lines in `MEMORY.md` of each
  project in the list of `<topic>/README.md`.

```
- [Test server](~/.claude/claude-memory/shared/test-server/) - shared: SSH access, database schema
  - [SSH access](~/.claude/claude-memory/shared/test-server/ssh-access.md) - user, key, jump host
```

For a team shared topic, change only your own `MEMORY.md` (in `users/<user>/`). Do not
change the personal memory of a different person. Tell the user which projects and persons
must add the topic line.

### 11.1 Make a topic, or move records into it

Do this only after the approval of the user (section 3.2).

1. Select a short name in kebab case, for example `test-server`. Select the role:
   personal (`users/<user>/shared/<topic>/`) or team (`shared/<topic>/`).
2. Make the directory and its `invalid/` subdirectory.
3. Write `<topic>/README.md`: one sentence about the topic, the rules, and the list of
   the projects that use it (`projects/<name>/`).
4. Move the records of the topic from the projects into the topic directory. Do not
   change their names, thus the links `[[name]]` stay correct. If two projects have a
   record with the same name, merge the two records into one (section 7.2, "Merge").
   For a team topic, the records must agree with section 12 (no absolute paths, no
   machine names).
5. Add a history line to each moved record: `moved to shared topic <topic>`.
6. In `MEMORY.md` of each project in the list: remove the lines of the moved records, and
   add the topic line in `## Groups` (and the record lines, if you use them).
7. Tell the user what you moved, and which `MEMORY.md` files you changed.

## 12. Team memory

The team memory of a project is in `<repo>/projects/<name>/team/`. All
persons that use the repository read it. The SessionStart hook gives you its index.

- **Approval.** Write, change, promote or invalidate a team record only after the user
  approved it. Show the full text of the record first.
- **No index file.** The SessionStart hook makes the index from the frontmatter
  (`name`, `description`, `status`) of the records. Thus two persons cannot get a
  conflict in an index. Write a good `description`: it is the index line.
- **Content.** A team record must be correct for all persons on all machines:
  - Paths only relative to the project root (`src/main.c:42`)
  - No absolute paths, no home directory paths, no links outside the project
  - No machine names, no person names other than in `history`, no credentials
- **Check.** The PreToolUse hook `sync.sh check-team` blocks a write with a forbidden
  pattern. The patterns are in `.memory-check` in the root of the repository, or in
  `team-memory-check.default`. If the hook blocks a write, move the machine detail to the
  local memory, and write only the general fact into the team memory. `sync.sh push` also
  keeps a file with a forbidden pattern out of the commit. The SessionStart hook then
  shows a warning. Tell the user.
- **Lifecycle.** The states and the review are the same (sections 7 to 9). Invalid team
  records go to `team/invalid/`, with `status: invalid` and a `description` that starts
  with `NOT TRUE since <YYYY-MM>:`.
- **Records of other persons.** You can promote or invalidate a record that a different
  person wrote, with evidence and with the approval of the user. Add a history line. Do
  not delete it.
- **Contradictions.** If a team record and a personal record contradict each other, tell
  the user. Do not select one yourself.
