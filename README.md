# Shell Utilities

Collection of simple shell functionalities to enhance your development workflow.

## Collection

### 1. `work.sh` - Project Quick Launcher

Quickly open VS Code in your project directories with smart tab completion.

#### Features

-   Opens VS Code in workspace directories under a configured base path
-   Tab completion for available project folders
-   Directory existence validation
-   Compatible with both bash and zsh
-   Optional terminal auto-close after launching VS Code

#### Usage

```bash
work [-c] <project-name>  # -c flag keep terminal alive after opening
```

Example:

```bash
work frontend  # Opens VS Code in /path/to/your/projects/frontend
```

Use TAB after typing `work` for directory autocompletion.

### 2. `sail-init.sh` - Laravel Sail Project Initializer

Automates the creation and initial setup of Laravel projects using Laravel Sail.

#### Features

-   Creates new Laravel project with Sail
-   Starts Docker containers automatically
-   Smart health checking for application readiness
-   Runs initial database migrations
-   Provides helpful feedback and progress indicators
-   Maximum 60-second timeout for startup

#### Usage

```bash
sail-init <project-name>
```

Example:

```bash
sail-init my-new-app
```

The script will:

1. Create a new Laravel project
2. Start Sail containers
3. Wait for the application to be ready (health checks)
4. Run database migrations
5. Display useful Sail commands

### 3. `file-organizer.sh` - File Organization Script

Organizes files with the same base name and different extensions into a dedicated folder.

#### Features

-   Moves files with specified base name and extensions into a new directory
-   Comprehensive error handling and input validation
-   Detailed logging to both console and log file
-   Compatible with both bash and zsh
-   Production-level script with best practices

#### Usage

```bash
file-organizer <base_name> <extension1> [extension2] ...
```

Example:

```bash
file-organizer myfile txt pdf doc  # Creates myfile/ and moves myfile.txt, myfile.pdf, myfile.doc into it
```

The script will:

1. Create a timestamped log file in /tmp
2. Validate all inputs and file existence
3. Create the target directory if needed
4. Move matching files
5. Clean up empty directories if no files were moved
6. Provide detailed feedback of all operations

### 4. `get-secret` (in `utils.sh`) - Secret Resolution Helper

Resolves a named secret for scripts that need API tokens or service credentials
(e.g. `cf-tunnel.sh`).

#### Resolution order

1. **1Password CLI** — `op read "op://Private/<name>/password"`
2. **macOS Keychain** (fallback) — `security find-generic-password -s "<name>" -a "$USER" -w`

If neither backend has the secret, it prints setup instructions for both and returns 1.
Set `SECRETS_DEBUG=1` to log (to stderr) which backend served a given secret; the happy
path is otherwise silent so it stays script-composable (`token="$(get-secret NAME)"`).

#### Migrating existing Keychain secrets to 1Password

`secret-migrate` (also in `utils.sh`) migrates one or more named secrets from Keychain
into 1Password. Run it interactively, by hand, whenever you need to migrate something:

```bash
secret-migrate CLICKUP_API_TOKEN SLITE_API_TOKEN
```

Or use the bin wrapper, which just passes its arguments straight through:

```bash
./bin/migrate-secrets-to-1password.sh CLICKUP_API_TOKEN SLITE_API_TOKEN cf-tunnel-tshallandale-prod-id cf-tunnel-tshallandale-prod-secret cf-tunnel-tshallandale-stg-id cf-tunnel-tshallandale-stg-secret
```

(those six were this repo's original known secrets — just an example, not a hardcoded
list anymore). For a one-off future token, just call `secret-migrate MY_NEW_TOKEN`
straight from the shell.

It requires the 1Password desktop app's CLI integration to be enabled (Settings ->
Developer -> "Integrate with 1Password CLI"), reads each named secret out of Keychain,
and creates/updates a matching item in the `Private` vault. It never prints secret
values. Existing scripts need no further changes — `get-secret` picks up 1Password
automatically once the item exists, and still falls back to Keychain for anything not
yet migrated.

### 5. `auto-nvm.sh` - Automatic Node Version Manager

Automatically switches Node.js versions when changing directories based on `.nvmrc` files.

#### Features

-   Automatically detects `.nvmrc` files in project directories
-   Switches Node.js version when changing directories
-   Installs required Node.js version if not present
-   Falls back to default version when leaving a project directory
-   Compatible with zsh shell
-   Integrates with nvm (Node Version Manager)

#### Usage

The functionality is automatic after installation. Simply:

```bash
cd your-project  # Auto-switches to Node version in .nvmrc
cd ..            # Auto-switches back to default Node version
```

Requirements:

-   zsh shell
-   nvm (Node Version Manager) installed and initialized

### 6. tmux + VSCode terminal integration

Keeps tmux window names in sync with VSCode integrated-terminal tab titles,
persists sessions/windows/pane layout across reboots, and gives you an
explicit way to end a tmux session from a tab (without that also happening
when VSCode just closes normally or crashes).

#### How it works

-   **Name sync (tmux → VSCode tab)**: `.tmux.conf` sets `set-titles on` /
    `set-titles-string '#W'`, which makes tmux push the current window's name
    into the terminal's OSC title sequence any time you rename a window
    (`ctrl-b ,`) or switch windows. `vscode/settings.json` sets
    `"terminal.integrated.tabs.title": "${sequence}"`, which makes the VSCode
    tab title just follow that OSC sequence. One rename (`ctrl-b ,`) updates
    both — there's no reverse direction (VSCode → tmux), since VSCode has no
    hook into a shell it doesn't control.

-   **Persistence across reboots**: `.tmux.conf` loads two TPM plugins,
    `tmux-resurrect` and `tmux-continuum`. Continuum autosaves the full
    session/window/pane layout (including names) every 15 minutes
    (`@continuum-save-interval 15`) and auto-restores it the next time the
    tmux server starts (`@continuum-restore on`), including captured pane
    contents (`@resurrect-capture-pane-contents on`). Without this, a fresh
    tmux server after a reboot has no memory of prior session/window names.

-   **Explicit "kill session" action**: closing a VSCode terminal tab (trash
    icon, `cmd+w`, the whole window closing, or VSCode crashing) all just
    close the tab's pty, which sends the shell/`tmux attach` client a
    `SIGHUP`. tmux's default behavior on `SIGHUP` is to **detach**, not kill —
    which is the whole point of using tmux here (the session survives VSCode
    closing for any reason). Since there's no reliable way to tell "user
    explicitly closed this one tab" apart from "the app is closing/crashing"
    at that layer, killing a session on purpose is a **separate, deliberate**
    keybinding instead of overloading the default close gesture:
    `vscode/keybindings.json` binds `ctrl+alt+w` (while a terminal has focus)
    to send `tmux kill-session ; exit` to the shell — ends the current tmux
    session and closes the tab in one action. Every other close path is
    untouched and still just detaches.

#### Replicating on a new machine

1. Symlink (or copy) `.tmux.conf` per the steps above (already covered by
   `setup.sh`).
2. Install [TPM](https://github.com/tmux-plugins/tpm) and the plugins it
   declares:

    ```bash
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    tmux new-session -d -s _tpm_setup -c ~ \
      && tmux run-shell -t _tpm_setup '~/.tmux/plugins/tpm/scripts/install_plugins.sh' \
      && tmux kill-session -t _tpm_setup
    ```

3. Copy `vscode/settings.json` and `vscode/keybindings.json` into
   `~/Library/Application Support/Code/User/` (merge by hand if you already
   have customizations there — these are snapshots of one machine's config,
   not meant to be blindly overwritten).
4. Reload the VSCode window (`Cmd+Shift+P` → "Reload Window") to pick up the
   new keybinding and terminal setting.

### 7. `bin/move-repo.sh` - Move a repo without breaking tool state

Moves a git repo to another folder and updates everything that stores its absolute path:

- Claude Code: the project folder (transcripts, memory), `~/.claude.json` and prompt history
- Orca's repo registration (skipped while Orca is running, since Orca would overwrite it; re-add the repo in Orca instead)
- Python `.venv` folders, rebuilt with `uv sync`
- `node_modules` folders, reinstalled with the repo's package manager (pnpm, bun, yarn or npm, picked by lockfile), since pnpm's `.bin` shims store absolute paths. A failed install is reported as a warning at the end instead of stopping the move
- direnv approval and git worktrees

Engram needs nothing: it names projects after the git remote, not the folder.

```bash
./bin/move-repo.sh ~/Desktop/work/my-repo ~/Desktop/work/personal             # dry run
DRY_RUN=0 ./bin/move-repo.sh ~/Desktop/work/my-repo ~/Desktop/work/personal   # apply
```

Run it from outside the repo. It refuses while any process (shell, Claude session, dev server) has its working directory inside the repo, so agents in other projects can keep running. Everything it edits is backed up first to `~/.local/state/move-repo/`.

## Installation

1. Clone the repository to the shell utilities directory:

```bash
git clone https://github.com/yourusername/shell-utils.git "${HOME}/shell-utils"
```

2. For `work.sh`, set your projects base path by editing the script or adding to your shell config:

```bash
export BASE_PATH="/path/to/your/projects"
```

3. Source the utilities and scripts in your shell configuration file:

```bash
# Add to ~/.bashrc or ~/.zshrc
source "${HOME}/shell-utils/src/utils.sh"
source "${HOME}/shell-utils/src/work.sh"
source "${HOME}/shell-utils/src/auto-nvm.sh"
...
```

or

```bash
eval "source ${HOME}/shell-utils/src/{utils,auto-nvm,work,...}.sh"
```

4. Create the logs directory:

```bash
mkdir -p "${HOME}/.logs/shell-utils"
```

5. Reload your shell configuration:

```bash
source ~/.bashrc  # or ~/.zshrc
```

## Directory Structure

```
${HOME}/
├── shell-utils/
│   ├── utils.sh
│   ├── work.sh
│   ├── sail.sh
│   └── file-organizer.sh
└── .logs/
    └── shell-utils/
        └── [script logs]
```

## Contributing

Feel free to suggest improvements or add new utilities to enhance the collection.

## License

[LICENSE](./LICENSE)
