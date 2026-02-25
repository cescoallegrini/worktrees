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

Clone the repo and source `wt.sh` from your shell config:

```sh
git clone https://github.com/yourusername/wt.git ~/.local/bin/wt
echo 'source ~/.local/bin/wt/wt.sh' >> ~/.zshrc
```

## Configuration

Create `~/.wt/config` to set global defaults. The file is sourced as a shell script.

```sh
# ~/.wt/config
DEFAULT_TARGET_DIR="$HOME/Projects"
```

| Variable | Description |
|----------|-------------|
| `DEFAULT_TARGET_DIR` | Default parent directory for `wt init`. When set, the target directory is derived from the repo name. |

## Commands

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

### `wt remove <branch>`

Remove a worktree and delete its local branch.

```sh
wt remove fix-login
```

Warns if there are uncommitted changes and asks for confirmation. Runs `pre-remove` and `post-remove` hooks.

### `wt list`

List all worktrees.

```sh
wt list
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

### Example: global `wt open`

A global command at `~/.wt/commands/open` that opens a worktree in your editor:

```sh
#!/bin/sh
# ~/.wt/commands/open
branch="$1"
[ -z "$branch" ] && echo "Usage: wt open <branch>" && exit 1

if [ "$branch" = "$WT_BASE_BRANCH" ]; then
  wt_path="$WT_ROOT_PATH/$WT_BASE_BRANCH"
else
  wt_path="$WT_ROOT_PATH/worktrees/$branch"
fi

code "$wt_path"
```

```sh
wt open fix-login
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
wt.sh                  # Entry point — source this from .zshrc
commands/
├── create.sh          # wt create
├── init.sh            # wt init
├── list.sh            # wt list
├── remove.sh          # wt remove
└── sync.sh            # wt sync
lib/
├── commands.sh        # Custom command dispatcher
├── config.sh          # Loads ~/.wt/config
├── hooks.sh           # Hook runner
└── root.sh            # Container root detection and branch helpers
```

## License

MIT
