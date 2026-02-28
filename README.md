# wt

A minimal CLI for managing [git worktrees](https://git-scm.com/docs/git-worktree) using a bare-repo layout.

`wt` is tool-agnostic — it handles the git plumbing and delegates everything else (dependency installation, editor setup, environment config) to hooks and custom commands.

## Layout

After running `wt init`, you get this structure:

```
my-project/
├── .bare/              # bare git repo
├── .wt/                # hooks and custom commands
│   ├── commands/
│   └── hooks/
├── main/               # primary worktree (named after the default branch)
└── worktrees/          # ephemeral worktrees
    ├── feature-login/
    └── fix-auth/
```

The primary worktree directory is named after the remote's default branch — `main`, `master`, or whatever the remote uses. It is detected automatically.

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/cescoallegrini/worktrees/main/install.sh | bash
```

This installs wt to `~/.wt/` and symlinks it to `~/.local/bin/wt`. Running it again updates to the latest version — your config and custom commands are preserved. Ensure `~/.local/bin` is on your `PATH`.

## Configuration

`~/.wt/config` is created on first install. Edit it to set global defaults:

```sh
# ~/.wt/config
DEFAULT_TARGET_DIR="$HOME/Projects"
```

| Variable | Description |
|----------|-------------|
| `DEFAULT_TARGET_DIR` | Default parent directory for `wt init`. Also used for interactive project selection when running commands outside a project (see [Project resolution](#project-resolution)). |

## Project resolution

All commands except `init` need to know which project to operate on. `wt` resolves this in order:

1. **`-p` / `--project` flag** — explicitly specify the project path
2. **Current directory** — walks up from `$PWD` looking for a `.bare/` directory
3. **Interactive picker** — if `DEFAULT_TARGET_DIR` is set and a TTY is available, presents a project picker (uses `fzf` if installed, numbered menu otherwise)
4. **Error** — with guidance to use `-p` or set `DEFAULT_TARGET_DIR`

In non-interactive environments, the picker is skipped and an error is returned instead.

```sh
# Explicit project
wt -p ~/Projects/api list

# From inside a project — just works
cd ~/Projects/api/main
wt list

# From anywhere with DEFAULT_TARGET_DIR set — interactive picker
cd ~
wt list
# → Select project:
#   1) api
#   2) frontend
# Choice [1-2]:
```

## Commands

### Global options

| Flag | Description |
|------|-------------|
| `-p`, `--project <path>` | Operate on a specific project. Must be placed before the subcommand. |

### `wt init <remote-url> [target-dir]`

Clone a repository as a bare repo and set up the worktree container.

```sh
# With DEFAULT_TARGET_DIR set to ~/Projects:
wt init git@github.com:org/api.git
# → clones into ~/Projects/api/

# Or specify the target explicitly:
wt init git@github.com:org/api.git ~/work/api
```

Creates the `.wt/commands/` and `.wt/hooks/` directories for you to add custom commands and hooks.

### `wt create <branch> [--from <base>]`

Create a new worktree.

```sh
wt create fix-login
wt create feature/v2 --from develop
```

Branch names containing `/` are normalized to `-` for the directory name (e.g. `feature/login` becomes `feature-login`).

If the branch already exists on the remote, it checks it out. Otherwise, it creates a new branch from the default branch (or the ref specified by `--from`).

The `--from` flag auto-resolves short names — `--from develop` will use `origin/develop` if `develop` doesn't exist locally.

Runs `pre-create` and `post-create` hooks.

### `wt sync`

Fetch from origin and fast-forward the primary worktree.

```sh
wt sync
```

Runs `pre-sync` and `post-sync` hooks.

### `wt remove [branch]`

Remove a worktree and delete its local branch. Without arguments, presents an interactive picker listing non-base worktrees.

```sh
wt remove fix-login  # direct
wt remove            # interactive picker
```

Warns if there are uncommitted changes and asks for confirmation. Runs `pre-remove` and `post-remove` hooks.

### `wt list`

List all worktrees with their current commit.

```
$ wt list
my-project — ~/Projects/my-project

Base:
  main     4e864a0 Fix TTY detection...

Worktrees:
  feature  cb6f456 Convert wt from...
  hotfix   abff7a3 Add --project...
```

## Hooks

Hooks let you define custom logic that runs at specific points in the worktree lifecycle. They live at `<root>/.wt/hooks/` and are created as empty directories by `wt init`.

### Available hooks

| Hook | Trigger | Use case |
|------|---------|----------|
| `pre-create` | Before `wt create` | Validate prerequisites, provision resources |
| `post-create` | After `wt create` | Install dependencies, copy env files |
| `pre-sync` | Before `wt sync` | Stash work, check for conflicts |
| `post-sync` | After `wt sync` | Reinstall dependencies after update |
| `pre-remove` | Before `wt remove` | Clean up external resources, close connections |
| `post-remove` | After `wt remove` | Notify, clean caches |

`pre-*` hooks abort the command on non-zero exit. `post-*` hooks warn but continue.

Hooks are executable files — any language works.

### Environment variables

All hooks and custom commands receive these environment variables:

| Variable | Description | Available in |
|----------|-------------|--------------|
| `WT_BARE_PATH` | Path to the bare repo (`.bare/`) | commands, hooks |
| `WT_BASE_BRANCH` | Remote's default branch name | commands, hooks |
| `WT_BRANCH` | Git branch name as-is (e.g. `feature/login`) | hooks |
| `WT_DIR_NAME` | Normalized directory name (e.g. `feature-login`) | hooks |
| `WT_HOOK` | Hook name | hooks |
| `WT_ROOT_PATH` | Worktree container root | commands, hooks |
| `WT_WORKTREE_PATH` | Full path to the target worktree | hooks |

### Examples

**Node.js monorepo** — `.wt/hooks/post-create`:

```sh
#!/bin/sh
# Symlink node_modules from the primary worktree
ln -s "$WT_ROOT_PATH/$WT_BASE_BRANCH/node_modules" "$WT_WORKTREE_PATH/node_modules"

# Symlink nested workspace node_modules
for nm in "$WT_ROOT_PATH/$WT_BASE_BRANCH"/packages/*/node_modules; do
  [ -d "$nm" ] || continue
  relative="${nm#$WT_ROOT_PATH/$WT_BASE_BRANCH/}"
  mkdir -p "$WT_WORKTREE_PATH/$(dirname "$relative")"
  ln -s "$nm" "$WT_WORKTREE_PATH/$relative"
done
```

**Python project** — `.wt/hooks/post-create`:

```sh
#!/bin/sh
cd "$WT_WORKTREE_PATH" && python -m venv .venv && .venv/bin/pip install -e ".[dev]"
```

**Rust project** — `.wt/hooks/post-create`:

```sh
#!/bin/sh
cd "$WT_WORKTREE_PATH" && cargo fetch
```

**No hooks needed** — just leave the hooks directory empty. Everything works without them.

## Custom commands

Any command that isn't built-in gets dispatched to a custom command script. These can be defined at two levels:

| Location | Priority | Scope |
|----------|----------|-------|
| `<root>/.wt/commands/<name>` | First | Per-project |
| `~/.wt/commands/<name>` | Fallback | Global, all projects |

Project commands take priority over global commands with the same name.

Custom commands receive `WT_BARE_PATH`, `WT_BASE_BRANCH`, and `WT_ROOT_PATH` as environment variables, plus any arguments passed after the command name.

### Shared utilities

Custom commands can source shared utility functions:

```sh
. "$HOME/.wt/lib/core/utils.sh"
```

This auto-loads all functions from `utils/`. Available utilities:

| Function | File | Description |
|----------|------|-------------|
| `wt_branch_path <branch>` | `utils/branch-path.sh` | Resolve a branch name to its worktree filesystem path. |
| `wt_pick <prompt>` | `utils/pick.sh` | Interactive picker — reads items from stdin, prints selection to stdout. Uses fzf if available, numbered menu fallback. Auto-selects when only one item. |
| `wt_select_branch` | `utils/select-branch.sh` | Collect all worktree branches and present an interactive picker. Returns the selected branch name. |

### Example: global `wt open`

A global command at `~/.wt/commands/open` that opens a worktree in your editor:

```sh
#!/bin/sh
# ~/.wt/commands/open
. "$HOME/.wt/lib/core/utils.sh"

branch="${1:-$(printf '%s\n' "$WT_BASE_BRANCH" | wt_pick "Select branch")}"
wt_path="$(wt_branch_path "$branch")"

code "$wt_path"
```

```sh
wt open fix-login  # direct
wt open            # interactive picker
```

### Example: project-specific command

A deploy command at `<root>/.wt/commands/deploy`:

```sh
#!/bin/sh
echo "Deploying from $WT_ROOT_PATH..."
# project-specific deploy logic
```

```sh
wt deploy staging
```

## Project structure

```
install.sh             # curl | bash installer
wt.sh                  # Entry point — standalone bash script
config.default         # Template copied to ~/.wt/config on first install
commands/
├── create.sh          # wt create
├── init.sh            # wt init
├── list.sh            # wt list
├── remove.sh          # wt remove
└── sync.sh            # wt sync
core/
├── commands.sh        # Custom command dispatcher
├── config.sh          # Loads ~/.wt/config
├── hooks.sh           # Hook runner
├── root.sh            # Project resolution and branch helpers
└── utils.sh           # Auto-loads all utils/*.sh
utils/                 # Shared utility functions (wt_pick, wt_branch_path, ...)
```

## License

MIT
