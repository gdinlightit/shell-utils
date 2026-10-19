#!/bin/bash
#
# Move a local git repo to another folder and fix the tool state keyed by its
# absolute path: Claude Code (project transcripts + memory, ~/.claude.json,
# prompt history), Orca's repo registration, Python venvs, direnv, git worktrees.
# Engram needs nothing: it names projects after the git remote, not the folder.
#
# Run it from outside the repo, with nothing running inside it (Claude sessions,
# shells, dev servers): it refuses otherwise. Agents in other projects can keep
# running. If Orca is open its state file is left alone (Orca would overwrite the
# edit); re-add the repo in Orca instead. Dry run by default; everything it
# edits is backed up first.
#
# Usage:
#   ./bin/move-repo.sh <repo-path> <new-parent-dir>             # dry run
#   DRY_RUN=0 ./bin/move-repo.sh <repo-path> <new-parent-dir>   # do it
#   FORCE=1 skips the running-processes check (testing only).

set -euo pipefail

[[ $# -eq 2 ]] || { sed -n '15,17p' "$0"; exit 1; }

DRY_RUN="${DRY_RUN:-1}"
OLD="$(cd "$1" && pwd -P)"
NEW_PARENT="$(cd "$2" && pwd -P)"
NAME="$(basename "$OLD")"
NEW="$NEW_PARENT/$NAME"

# Claude Code names a project dir after its path with every non-alphanumeric char as '-'.
OLD_DASH="${OLD//[^a-zA-Z0-9]/-}"
NEW_DASH="${NEW//[^a-zA-Z0-9]/-}"
CLAUDE_PROJ="$HOME/.claude/projects"
ORCA_DATA="$HOME/Library/Application Support/orca/profiles/local-default/orca-data.json"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/move-repo/$NAME-$(date +%Y%m%d-%H%M%S)"

run() { echo "+ $*"; [[ "$DRY_RUN" == 1 ]] || "$@"; }

# Regex for a path followed by a boundary, so /w/foo never matches inside /w/foobar.
boundary() { printf '(%s)([^A-Za-z0-9._-]|$)' "$(printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"; }
OLD_RE="$(boundary "$OLD")"
OLD_DASH_RE="$(boundary "$OLD_DASH")"

# Rewrite both path forms in each file that contains them.
rewrite() {
  local f
  while IFS= read -r f; do
    run sd -- "$OLD_RE" "${NEW//\$/\$\$}\${2}" "$f"
    run sd -- "$OLD_DASH_RE" "${NEW_DASH}\${2}" "$f"
  done < <(rg -l -e "$OLD_RE" -e "$OLD_DASH_RE" "$@" 2>/dev/null || true)
}

# --- preflight ---
inside() { [[ "$1" == "$OLD" || "$1" == "$OLD"/* ]]; }
inside "$(pwd -P)" && { echo "Run this from outside $OLD"; exit 1; }
if [[ "${FORCE:-0}" != 1 ]]; then
  busy="$(lsof -d cwd -F pcn 2>/dev/null | awk -v old="$OLD" '
    /^p/ {p = substr($0, 2)} /^c/ {c = substr($0, 2)}
    /^n/ {n = substr($0, 2); if (n == old || index(n, old "/") == 1) print "  " p " " c}')"
  [[ -z "$busy" ]] || { printf 'Processes running inside the repo (quit them first):\n%s\n' "$busy"; exit 1; }
fi
ORCA_RUNNING=0
procs="$(ps -axo command)"   # not piped: rg -q exits early and pipefail would see SIGPIPE
rg -q '^/Applications/Orca.app/Contents/MacOS/Orca$' <<<"$procs" && ORCA_RUNNING=1
[[ "$NEW" == "$OLD" || "$NEW" == "$OLD"/* ]] && { echo "Target is inside the repo"; exit 1; }
[[ -e "$NEW" ]] && { echo "$NEW already exists"; exit 1; }
git -C "$OLD" rev-parse --git-dir >/dev/null 2>&1 || { echo "$OLD is not a git repo"; exit 1; }
[[ -z "$(git -C "$OLD" status --porcelain)" ]] || { echo "Repo has uncommitted changes"; exit 1; }
HAS_WORKTREES=0
[[ "$(git -C "$OLD" worktree list | wc -l)" -gt 1 ]] && HAS_WORKTREES=1
# Venv dirs relative to the repo root, e.g. "/backend". Collected before the move.
VENV_DIRS=()
while IFS= read -r v; do VENV_DIRS+=("$(dirname "${v#"$OLD"}")"); done \
  < <(fd -H -I -t d -g '.venv' --max-depth 4 -E node_modules "$OLD" | sed 's:/$::')

echo "Moving $OLD -> $NEW (DRY_RUN=$DRY_RUN)"

# --- backups ---
run mkdir -p "$BACKUP"
run cp "$HOME/.claude.json" "$BACKUP/claude.json"
[[ -f "$HOME/.claude/history.jsonl" ]] && run cp "$HOME/.claude/history.jsonl" "$BACKUP/history.jsonl"
[[ -f "$ORCA_DATA" ]] && run cp "$ORCA_DATA" "$BACKUP/orca-data.json"
[[ -d "$CLAUDE_PROJ/$OLD_DASH" ]] && run tar -czf "$BACKUP/claude-project.tgz" -C "$CLAUDE_PROJ" -- "$OLD_DASH"

# --- 1. repo ---
run mv "$OLD" "$NEW"
[[ "$HAS_WORKTREES" == 1 ]] && run git -C "$NEW" worktree repair

# Venvs hardcode absolute paths in activate scripts and shebangs: rebuild them.
for dir in ${VENV_DIRS[@]+"${VENV_DIRS[@]}"}; do
  dir="${dir%/}"
  run rm -rf "$NEW$dir/.venv"
  if [[ -f "$OLD$dir/pyproject.toml" || -f "$NEW$dir/pyproject.toml" ]]; then
    run uv sync --project "$NEW$dir"
  fi
done

# direnv approvals are keyed by path.
[[ -f "$OLD/.envrc" ]] && run direnv allow "$NEW"

# --- 2. Claude Code project dir (transcripts + memory/) ---
if [[ -d "$CLAUDE_PROJ/$OLD_DASH" ]]; then
  run mv "$CLAUDE_PROJ/$OLD_DASH" "$CLAUDE_PROJ/$NEW_DASH"
  if [[ "$DRY_RUN" == 1 ]]; then rewrite "$CLAUDE_PROJ/$OLD_DASH"; else rewrite "$CLAUDE_PROJ/$NEW_DASH"; fi
fi
for d in "$CLAUDE_PROJ/$OLD_DASH"-*; do
  [[ -d "$d" ]] && echo "note: $d may belong to a subfolder of this repo; left as is"
done

# --- 3. Orca, prompt history, then ~/.claude.json last (every running Claude session writes it) ---
if [[ "$ORCA_RUNNING" == 1 ]]; then
  echo "note: Orca is running, its state file is left alone"
elif [[ -f "$ORCA_DATA" ]]; then
  rewrite "$ORCA_DATA"
fi
rewrite "$HOME/.claude/history.jsonl"
rewrite "$HOME/.claude.json"
[[ "$DRY_RUN" == 1 ]] || jq empty "$HOME/.claude.json"

# --- verify ---
if [[ "$DRY_RUN" == 1 ]]; then
  echo "Dry run only. Re-run with DRY_RUN=0 to apply."
else
  sleep 3   # give running Claude sessions a chance to write ~/.claude.json back
  echo "--- leftovers (expect none) ---"
  check=("$HOME/.claude.json" "$HOME/.claude/history.jsonl" "$CLAUDE_PROJ/$NEW_DASH")
  [[ "$ORCA_RUNNING" == 1 ]] || check+=("$ORCA_DATA")
  rg -l -e "$OLD_RE" "${check[@]}" 2>/dev/null \
    && echo "(if ~/.claude.json is listed, another Claude session wrote it back; it only holds per-project settings, so re-running the rewrite is optional)" \
    || true
  echo "Done. Backup: $BACKUP"
  [[ "$ORCA_RUNNING" == 1 ]] && echo "Orca: remove $NAME and add $NEW again."
  echo "Next: cd $NEW && claude --resume"
fi
