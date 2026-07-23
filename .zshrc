
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH=/opt/homebrew/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(
  zsh-syntax-highlighting
  zsh-autosuggestions

  git

  npm
  node
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes.

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=180"

# makes the GNU grep the default instead of the MacOS one
# needed for phpenv: https://github.com/phpenv/phpenv/issues/109
PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# pyenv install python dependencies
export LDFLAGS="-L/opt/homebrew/opt/zlib/lib $LDFLAGS"
export CPPFLAGS="-I/opt/homebrew/opt/zlib/include $CPPFLAGS"
export LDFLAGS="-L/opt/homebrew/opt/tcl-tk@8/lib $LDFLAGS"
export CPPFLAGS="-I/opt/homebrew/opt/tcl-tk@8/include $CPPFLAGS"
export PKG_CONFIG_PATH="/opt/homebrew/opt/zlib/lib/pkgconfig"

# pnpm
export PNPM_HOME="/Users/guidodinello/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if command -v ngrok &>/dev/null; then
  eval "$(ngrok completion)"
fi

# my aliases
files=("${HOME}/Desktop/work/aliases/src/"{utils,work,auto-nvm,auto-pvm,sail,file-organizer,aws-ssm-tunnel,cf-tunnel}".sh")
for file in "${files[@]}"; do
  source "$file"
done

alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'
alias sail-debug='sail shell -c "cd storage/logs && touch laravel-$(date +%Y-%m-%d).log && tail -f laravel-$(date +%Y-%m-%d).log"'
copy-tree() {
    tree -a -I '.git|node_modules|vendor|.github|.million|cache|.vscode|deployment|public|reports|stubs|storage|.claudesync' "$@" | pbcopy
}
alias copy-tree-content='fd -e html -e ts -e tsx -e jsx -e json -e mts -e jsonc -e php -e stub -e py\
  --exclude "*lock.json" \
  --exclude "*.lock" \
  --exclude "node_modules" \
  --exclude "vendor" \
  --exclude ".git" \
  --exclude ".vscode" \
  --exec echo "=== {} ===" \; \
  --exec cat {} \; \
  --exec echo "" \; | pbcopy'

. "$HOME/.local/bin/env"
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

# opencode
export PATH=/Users/guidodinello/.opencode/bin:$PATH
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/guidodinello/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
eval "$(direnv hook zsh)"
[ -f ~/.secrets ] && source ~/.secrets

# Auto tmux in VS Code integrated terminal
if [[ "$TERM_PROGRAM" == "vscode" && -z "$TMUX" ]] && command -v tmux >/dev/null; then
  session_name="${PWD##*/}"
  session_name="${session_name:-root}"
  exec tmux new-session -A -s "$session_name"
fi

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
