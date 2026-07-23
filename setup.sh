#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

link() {
  local src="$REPO_DIR/$1"
  local dst="$HOME/$1"
  if [[ -L "$dst" ]]; then
    echo "  already symlinked: $1"
  elif [[ -f "$dst" ]]; then
    echo "  backing up $1 → $1.bak"
    mv "$dst" "$dst.bak"
    ln -s "$src" "$dst"
    echo "  symlinked: $1"
  else
    ln -s "$src" "$dst"
    echo "  symlinked: $1"
  fi
}

echo "Linking dotfiles from $REPO_DIR → $HOME"
link ".zshrc"
link ".tmux.conf"
echo "Done."
