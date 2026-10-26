#!/bin/bash
#
# Move one Claude Code session to another project folder, and optionally the
# Engram memories it saved: the transcript (+ its subagents/tool-results dir)
# moves to the new folder's project dir with its "cwd" fields rewritten, and
# each listed memory is re-created in the target Engram project (same content,
# dates and relations between moved memories) before the original is
# soft-deleted.
#
# Pick the memory ids yourself: a session often saves memories that belong to
# the old project. Engram has no "change project" operation, hence the
# export -> import -> soft-delete dance; relations to memories left behind are
# dropped (Engram doesn't relate memories across projects).
#
# Close the session first: it refuses while a process still has it open.
# Claude Code's auto mode blocks agents from editing transcripts, so run it
# yourself. Dry run by default; everything it edits is backed up first.
#
# Usage:
#   ./bin/move-session.sh <session-id> <new-folder> [obs-id...]             # dry run
#   DRY_RUN=0 ./bin/move-session.sh <session-id> <new-folder> [obs-id...]   # do it
#   ENGRAM_PROJECT=name overrides the target Engram project (default: the git
#   remote's repo name, or the folder name when there is no remote).

set -euo pipefail

[[ $# -ge 2 ]] || { sed -n '19,23p' "$0"; exit 1; }

DRY_RUN="${DRY_RUN:-1}"
ID="$1"
NEW="$(cd "$2" && pwd -P)"
shift 2
OBS_IDS=("$@")

CLAUDE_PROJ="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
ENGRAM_DB="${ENGRAM_DATA_DIR:-$HOME/.engram}/engram.db"
NEW_DASH="${NEW//[^a-zA-Z0-9]/-}"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/move-session/$ID-$(date +%Y%m%d-%H%M%S)"

run() { echo "+ $*"; [[ "$DRY_RUN" == 1 ]] || "$@"; }
sql() { sqlite3 -readonly "$ENGRAM_DB" "$@"; }

# --- preflight ---
[[ "$ID" =~ ^[0-9a-f-]{36}$ ]] || { echo "Not a session id: $ID"; exit 1; }
OLD_FILE="$(fd -t f -d 2 -F "$ID.jsonl" "$CLAUDE_PROJ" | head -1)"
[[ -n "$OLD_FILE" ]] || { echo "No transcript for $ID under $CLAUDE_PROJ"; exit 1; }
OLD_DIR="$(dirname "$OLD_FILE")"
NEW_DIR="$CLAUDE_PROJ/$NEW_DASH"
[[ "$OLD_DIR" != "$NEW_DIR" ]] || { echo "Session already lives in $NEW"; exit 1; }
[[ ! -e "$NEW_DIR/$ID.jsonl" && ! -e "$NEW_DIR/$ID" ]] || { echo "$NEW_DIR already has $ID"; exit 1; }
# A resumed session has its id in argv; a fresh one doesn't, so also refuse
# while the transcript was written in the last 2 minutes. FORCE=1 skips both.
if [[ "${FORCE:-0}" != 1 ]]; then
  procs="$(ps -axo comm=,args=)"   # not piped: rg -q exits early and pipefail would see SIGPIPE
  rg -q "^\S*claude\s.*$ID" <<<"$procs" && { echo "Session $ID is still running, close it first"; exit 1; }
  age=$(( $(date +%s) - $(stat -f %m "$OLD_FILE") ))
  [[ "$age" -ge 120 ]] || { echo "Transcript written ${age}s ago, is the session still open? (FORCE=1 to skip)"; exit 1; }
fi
OLD_CWD="$(jq -r 'select(.cwd) | .cwd' "$OLD_FILE" | head -1)"
FROM="\"cwd\":\"$OLD_CWD\""
TO="\"cwd\":\"$NEW\""

if [[ ${#OBS_IDS[@]} -gt 0 ]]; then
  for o in "${OBS_IDS[@]}"; do [[ "$o" =~ ^[0-9]+$ ]] || { echo "Not an observation id: $o"; exit 1; }; done
  IN="$(IFS=,; echo "${OBS_IDS[*]}")"
  [[ "$(sql "select count(*) from observations where id in ($IN) and deleted_at is null")" == "${#OBS_IDS[@]}" ]] \
    || { echo "Some observations don't exist or are deleted: $IN"; exit 1; }
  SRC_PROJECTS="$(sql "select distinct project from observations where id in ($IN)")"
  [[ "$(wc -l <<<"$SRC_PROJECTS")" -eq 1 ]] || { printf 'Observations span several projects:\n%s\n' "$SRC_PROJECTS"; exit 1; }
  SRC_PROJECT="$SRC_PROJECTS"
  if [[ -z "${ENGRAM_PROJECT:-}" ]]; then
    remote="$(git -C "$NEW" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$remote" ]]; then ENGRAM_PROJECT="$(basename "$remote" .git)"; else ENGRAM_PROJECT="$(basename "$NEW")"; fi
  fi
  [[ "$ENGRAM_PROJECT" != "$SRC_PROJECT" ]] || { echo "Memories are already in $ENGRAM_PROJECT"; exit 1; }
  TARGET_SESSION="manual-save-$ENGRAM_PROJECT"
fi

echo "Moving session $ID: $OLD_CWD -> $NEW (DRY_RUN=$DRY_RUN)"
echo "  cwd fields to rewrite: $(rg -c -F -- "$FROM" "$OLD_FILE" || echo 0)"
[[ ${#OBS_IDS[@]} -gt 0 ]] && echo "  memories: ${#OBS_IDS[@]} from $SRC_PROJECT -> $ENGRAM_PROJECT"

# --- backups ---
run mkdir -p "$BACKUP"
files=("$ID.jsonl"); [[ -d "$OLD_DIR/$ID" ]] && files+=("$ID")
run tar -czf "$BACKUP/claude-session.tgz" -C "$OLD_DIR" -- "${files[@]}"
[[ ${#OBS_IDS[@]} -gt 0 ]] && run sqlite3 "$ENGRAM_DB" ".backup '$BACKUP/engram.db'"

# --- 1. Claude transcript ---
run mkdir -p "$NEW_DIR"
run mv "$OLD_FILE" "$NEW_DIR/"
[[ -d "$OLD_DIR/$ID" ]] && run mv "$OLD_DIR/$ID" "$NEW_DIR/"
echo "+ rewrite $FROM -> $TO in $ID.jsonl and its subagents"
if [[ "$DRY_RUN" != 1 ]]; then
  sd -F -- "$FROM" "$TO" "$NEW_DIR/$ID.jsonl"
  [[ -d "$NEW_DIR/$ID" ]] && fd -e jsonl . "$NEW_DIR/$ID" -x sd -F -- "$FROM" "$TO" {}
  jq empty "$NEW_DIR/$ID.jsonl"
fi

# --- 2. Engram memories ---
if [[ ${#OBS_IDS[@]} -gt 0 ]]; then
  EXPORT="$BACKUP/export.json"
  IMPORT="$BACKUP/import.json"
  if [[ "$DRY_RUN" == 1 ]]; then EXPORT="$(mktemp)"; IMPORT="$(mktemp)"; trap 'rm -f "$EXPORT" "$IMPORT"' EXIT; fi
  engram export "$EXPORT" --project "$SRC_PROJECT" >/dev/null 2>&1

  # Fresh sync ids so the copies don't collide with the originals; relations
  # are kept only when both ends move, and get fresh ids too.
  ids_json="[$IN]"
  map="$(jq -r --argjson ids "$ids_json" '.observations[] | select(.id as $i | $ids | index($i)) | .sync_id' "$EXPORT" \
    | while read -r s; do printf '{"key":"%s","value":"obs-%s"}\n' "$s" "$(openssl rand -hex 8)"; done | jq -s from_entries)"
  # Only add the target bucket session when Engram doesn't have it yet.
  session='[]'
  [[ -n "$(sql "select 1 from sessions where id='$TARGET_SESSION'")" ]] \
    || session="$(jq -n --arg id "$TARGET_SESSION" --arg p "$ENGRAM_PROJECT" --arg d "$NEW" \
      '[{id: $id, project: $p, ownership_mode: "project_owned", directory: $d, started_at: (now | strftime("%Y-%m-%d %H:%M:%S"))}]')"
  jq --argjson ids "$ids_json" --argjson map "$map" --argjson session "$session" \
     --arg p "$ENGRAM_PROJECT" --arg s "$TARGET_SESSION" '
    {version, exported_at, sessions: $session, prompts: [],
     observations: [.observations[] | select(.id as $i | $ids | index($i))
       | del(.id) | .sync_id = $map[.sync_id] | .project = $p | .session_id = $s],
     relations: [.relations[] | select($map[.source_id] and $map[.target_id])
       | .source_id = $map[.source_id] | .target_id = $map[.target_id] | del(.sync_id)]}' "$EXPORT" > "$IMPORT"
  # Relations need their own fresh ids.
  jq '.relations |= map(.sync_id = "rel-" + .source_id[4:12] + .target_id[4:12])' "$IMPORT" > "$IMPORT.tmp" && mv "$IMPORT.tmp" "$IMPORT"
  touched="$(jq --argjson ids "$ids_json" '[.observations[] | select(.id as $i | $ids | index($i)) | .sync_id] as $s
    | [.relations[] | select((.source_id as $x | $s | index($x)) or (.target_id as $x | $s | index($x)))] | length' "$EXPORT")"
  echo "  relations: $(jq '.relations | length' "$IMPORT") kept, $((touched - $(jq '.relations | length' "$IMPORT"))) dropped (other end stays behind)"

  run engram import "$IMPORT"
  if [[ "$DRY_RUN" != 1 ]]; then
    copies="$(sql "select count(*) from observations a join observations b
      on a.title = b.title and a.content = b.content and a.created_at = b.created_at
      where a.id in ($IN) and b.project = '$ENGRAM_PROJECT' and b.deleted_at is null")"
    [[ "$copies" == "${#OBS_IDS[@]}" ]] \
      || { echo "Only $copies/${#OBS_IDS[@]} copies verified; originals left in place. Backup: $BACKUP"; exit 1; }
  fi
  for o in "${OBS_IDS[@]}"; do run engram delete "$o"; done
fi

# --- verify ---
if [[ "$DRY_RUN" == 1 ]]; then
  echo "Dry run only. Re-run with DRY_RUN=0 to apply."
else
  echo "--- leftovers (expect 0) ---"
  echo "old cwd fields: $(rg -c -F -- "$FROM" "$NEW_DIR/$ID.jsonl" || echo 0)"
  echo "Done. Backup: $BACKUP"
  echo "Next: cd $NEW && claude --resume $ID"
fi
