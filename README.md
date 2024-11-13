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

#### Installation

1. Set your projects base path in the script:
```bash
export BASE_PATH="/path/to/your/projects"
```

2. Source the script in your shell configuration file:
```bash
# Add to ~/.bashrc or ~/.zshrc
source /path/to/work.sh
```

3. Reload your shell configuration:
```bash
source ~/.bashrc  # or ~/.zshrc
```

#### Usage

```bash
work <project-name>
```

Example:
```bash
work frontend  # Opens VS Code in /path/to/your/projects/frontend
```

Use TAB after typing `work` for directory autocompletion.

## Contributing

Feel free to suggest improvements or add new utilities to enhance the collection.

## License

[Add your preferred license here]