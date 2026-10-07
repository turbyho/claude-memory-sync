# Installation of claude-memory-sync: instructions for Claude

This file is for Claude Code. It gives the procedure to install the memory sync on one
machine. The user starts it with a prompt of README.md, section 4.2. README.md explains
the structure (section 2) and the setups (section 3).

In this file:

- `TEMPLATE` is `https://github.com/turbyho/claude-memory-sync.git`.
- `MAIN` is the URL of the main memory repository of the user (from the prompt).
- `REPO` is `~/.claude/claude-memory`.
- `sync.sh` is `~/.claude/claude-memory/sync.sh`.

## 1. Rules

- Do not push memory to `TEMPLATE` or to a public remote. If `MAIN` is equal to
  `TEMPLATE`, stop and tell the user.
- Do not overwrite or delete an existing file or directory.
- Do not change `sync.sh`.
- Make each step idempotent. If a step is done already, skip it and tell the user.
- If a step fails, stop. Tell the user the command, the output and the possible cause.
  Do not repair it yourself.

## 2. Get the inputs

1. Get `MAIN` from the prompt. If the prompt does not give it, ask the user.
2. Make sure that the user said that `MAIN` is a private repository. If not, ask.
3. Get the list of project directories to enable. The list can be empty.
4. Get the project repositories to add: alias, URL, and the projects to enable in each.
   The list can be empty.

## 3. Do a check of the machine

1. The system must be Linux or macOS (`uname -s`). On native Windows, stop and tell the
   user that the sync does not support it yet.
2. `git --version` must be 2.31 or later.
3. `git config user.email` must give a value. If not, ask the user for the email address,
   and set it with `git config --global user.email`.
4. Access to `MAIN` must operate without a prompt:

   ```sh
   GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10" git ls-remote MAIN
   ```

   If the command fails, stop. Tell the user to set up an SSH key or an SSH agent.
5. `jq` or `python3` must be installed. If none is, stop and tell the user.
6. Look at `REPO`:
   - It does not exist: continue with section 4.
   - It is a git clone with `origin` equal to `MAIN`: skip section 4.
   - Other state: stop, tell the user what is in `REPO`, and ask what to do.

## 4. Clone the main repository

The output of `git ls-remote MAIN` (section 3, step 4) tells you which case applies.

**`MAIN` is empty (no refs):** the first machine of the first person. Start from the
latest release, not from the branch `main` of `TEMPLATE`:

```sh
git clone TEMPLATE ~/.claude/claude-memory
cd ~/.claude/claude-memory
git reset -q --hard "$(git tag -l 'v*' --sort=-v:refname | head -n 1)"
git remote rename origin upstream
git remote add origin MAIN
git push -u origin main
```

**`MAIN` has a branch `main`:** a person used the repository before:

```sh
git clone MAIN ~/.claude/claude-memory
git -C ~/.claude/claude-memory remote add upstream TEMPLATE
```

If `REPO/sync.sh` does not exist after the clone, the repository has memory, but no tool
(for example a project repository of an other person). Put the latest release into it. The
repository keeps its own version of a file that the tool also has:

```sh
cd ~/.claude/claude-memory
git fetch -q --tags upstream
git merge --allow-unrelated-histories -X ours -m "Add claude-memory-sync" \
  "$(git tag -l 'v*' --sort=-v:refname | head -n 1)"
git push
```

Make sure that `REPO/sync.sh` is executable.

## 5. Set up the machine

1. Run `sync.sh setup`. It adds the hooks to `~/.claude/settings.json` (with a backup),
   the import line to `~/.claude/CLAUDE.md` and the skill symlink. Each step changes
   nothing if it is done already.
2. If the command fails, or shows that it did not change a file because the file is in a
   different state, stop. Tell the user the output.

## 6. Person name

1. Run `sync.sh user`. Tell the user the person name.
2. The name must be the same on all machines of the user. If the user has an other
   machine with the sync and the name is different, set the email in the clone:
   `git -C ~/.claude/claude-memory config user.email <email of the other machine>`.

## 7. Repositories and projects

1. Run `sync.sh pull < /dev/null`. It clones the project repositories that the user added
   on an other machine.
2. Run `sync.sh list`. It shows the projects, their repositories and their persons. Do
   not enable a project again that is enabled for this person.
3. For each project repository of the prompt: `sync.sh add-repo <alias> <url>`. Make sure
   that the access operates without a prompt (section 3, step 4) first.
4. For each project directory of the prompt:
   1. Make sure that the directory exists. If not, tell the user and continue with the
      next directory.
   2. Run `sync.sh enable <dir>`, or `sync.sh enable <dir> --repo <alias>` for a project
      of a project repository.
   3. Look at the project name in the output. If the project has no git remote `origin`,
      tell the user that the name comes from the directory name. The directory must have
      the same name on each machine and for each person.

## 8. Do a check of the result

1. `sync.sh version`: the machine setup must be equal to the needed setup.
2. `sync.sh status <dir>` for each enabled project: the memory must be a symlink into
   `<repo>/projects/<name>/users/<user>/`.
3. `git -C ~/.claude/claude-memory status -sb` must show `## main...origin/main` with no
   changes. Do the same for each clone in `~/.claude/claude-memory.d/`.
4. `~/.claude/skills/memory-lifecycle/SKILL.md` must be readable.

## 9. Report to the user

Tell the user:

- The changed files and the paths of the backups
- The person name, the machine name, the repositories, and the enabled projects with
  their names
- That a new Claude Code session is necessary, because Claude Code loads the hooks at the
  start of a session
- That each person with access to a repository can read all its memory
- What to do on the other machines and for other persons: the prompts of README.md,
  section 4.2
