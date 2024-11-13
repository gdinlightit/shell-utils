# Shell Utilities

Collection of simple shell functionalities to enhance your development workflow.

## Collection

### 1. `work.sh` - Project Quick Launcher

Quickly open VS Code in your project directories with smart tab completion.

#### Features

- Opens VS Code in workspace directories under a configured base path
- Tab completion for available project folders
- Directory existence validation
- Compatible with both bash and zsh
- Optional terminal auto-close after launching VS Code

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

- Creates new Laravel project with Sail
- Starts Docker containers automatically
- Smart health checking for application readiness
- Runs initial database migrations
- Provides helpful feedback and progress indicators
- Maximum 60-second timeout for startup

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

## Installation

1. Clone or download the scripts to your local machine
2. For `work.sh`, set your projects base path in the script:

```bash
export BASE_PATH="/path/to/your/projects"
```

3. Source the scripts in your shell configuration file:

```bash
# Add to ~/.bashrc or ~/.zshrc
source /path/to/work.sh
source /path/to/sail-init.sh
```

4. Reload your shell configuration:

```bash
source ~/.bashrc  # or ~/.zshrc
```

## Contributing

Feel free to suggest improvements or add new utilities to enhance the collection.

## License

[LICENSE](./LICENSE)
