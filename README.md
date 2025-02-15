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

### 4. `auto-nvm.sh` - Automatic Node Version Manager

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
