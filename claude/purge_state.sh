#!/usr/bin/env bash
# Purge Claude Code and Claude Desktop state on macOS: memory, history, jobs,
# session data, temp files, logs, caches, VM bundles and the git worktrees
# Claude checked out.
#
# Both installs keep working. Login and keychain credentials, ~/.claude.json,
# settings, plugins and skills are left alone.
#
# Worktrees under <repo>/.claude/worktrees go through `git worktree remove`
# without --force, so git itself refuses any that holds modified or untracked
# files, and that one is kept. Branches and commits stay in the parent
# repository — only the checkout directory goes.
#
# --delete stops every running Claude process first, because a live session
# rewrites its transcript and memory on exit. It refuses to run inside a Claude
# Code session, which it would kill partway through; use a plain terminal.
#
# Dry run by default. Pass --delete to actually purge.
#
# Usage: purge_state.sh [--delete]

set -euo pipefail

delete=""
[ "${1:-}" = "--delete" ] && { delete=1; shift; }
[ $# -eq 0 ] || { echo "usage: $(basename "$0") [--delete]" >&2; exit 1; }

if [ -n "$delete" ] && [ -n "${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]; then
  echo "refusing to purge from inside a Claude Code session; run it from a plain terminal" >&2
  exit 1
fi

claude="$HOME/.claude"
desktop="$HOME/Library/Application Support/Claude"

targets=(
  # memory and history
  "$claude"/{projects,history.jsonl,plans,file-history}
  "$HOME"/.claude.bak-*
  # jobs and session state
  "$claude"/{jobs,tasks,sessions,session-env,daemon.log}
  "$claude"/daemon/{roster.json,dispatch,attach-journal}
  # temp files and logs
  "$claude"/{telemetry,backups,feedback,security,paste-cache,shell-snapshots}
  "$HOME"/.claude.json.backup "$HOME"/.claude.json.tmp.*
  "$HOME"/.claude-server-commander/{tool-history.jsonl,claude_tool_call.log}
  "/private/tmp/claude-$(id -u)" "/private/tmp/claude-mcp-browser-bridge-$(id -un)"
  "$HOME/Library/Logs/Claude"
  # caches; plugins/cache is the installed plugin code, so it stays
  "$claude"/{cache,gh-pr-status-cache.json,mcp-needs-auth-cache.json,stats-cache.json}
  "$claude/plugins/plugin-catalog-cache.json"
  "$HOME"/Library/Caches/{claude-cli-nodejs,com.anthropic.claudefordesktop,com.anthropic.claudefordesktop.ShipIt}
  # Desktop caches. Cookies, Local Storage, IndexedDB and Partitions hold the
  # login session and stay.
  "$desktop"/{Cache,"Code Cache",GPUCache,DawnGraphiteCache,DawnWebGPUCache,fcache}
  "$desktop"/{blob_storage,"Shared Dictionary",shared_proto_db,sentry,Crashpad}
  # Desktop session data and its VM. Desktop downloads the VM image again
  # (about 1.2G) on next use; the VM's own session disk comes back empty.
  "$desktop"/{claude-code-sessions,pending-uploads,vm_bundles,claude-code-vm}
)
[ -z "${TMPDIR:-}" ] || targets+=("${TMPDIR%/}"/claude-*)

# ~/.remember also holds the Remember plugin's own config, which stays.
for path in "$HOME/.remember"/*; do
  [ "${path##*/}" = config.json ] || targets+=("$path")
done
# Synced skills sit beside the Desktop session data and are not session data.
for path in "$desktop/local-agent-mode-sessions"/*; do
  [ "${path##*/}" = skills-plugin ] || targets+=("$path")
done
# Remember plugin history: one .remember per project directory it has run in.
while IFS= read -r -d '' path; do
  targets+=("$path")
done < <(find "$HOME/git" -maxdepth 8 -type d \( -name node_modules -o -name .git -o -name .venv \) -prune \
  -o -type d -name .remember -print0 -prune 2>/dev/null)

if [ -n "$delete" ]; then
  # TERM lets a session write its last state before the removals; KILL takes
  # whatever is left.
  for signal in TERM KILL; do
    pkill "-$signal" -x claude || true
    pkill "-$signal" -x Claude || true
    pkill "-$signal" -f 'claude daemon' || true
    sleep 2
  done
fi

for path in "${targets[@]}"; do
  [ -e "$path" ] || [ -L "$path" ] || continue
  if [ -z "$delete" ]; then
    printf 'would remove: %5s  %s\n' "$(du -sh "$path" 2>/dev/null | cut -f1 | tr -d ' ')" "$path"
  elif rm -rf "$path"; then
    echo "removed: $path"
  else
    echo "could not remove: $path" >&2
  fi
done

# Worktrees, found at ~/git/<host>/<org>/<repo>/.claude/worktrees. They come
# after the removals so Remember history inside one does not make git refuse it.
for wt in "$HOME"/git/*/*/*/.claude/worktrees/*; do
  [ -f "$wt/.git" ] || continue
  [ ! -L "$wt" ] || continue
  repo="${wt%/.claude/worktrees/*}"
  if [ -n "$delete" ]; then
    if reason=$(git -C "$repo" worktree remove "$wt" 2>&1); then
      echo "removed worktree: $wt"
    else
      echo "kept worktree: $wt (${reason#fatal: })"
    fi
  elif [ -n "$(git -C "$wt" status --porcelain -- . ':(exclude).remember' 2>/dev/null)" ]; then
    echo "would keep worktree, has uncommitted or untracked files: $wt"
  else
    echo "would remove worktree: $wt"
  fi
done

if [ -z "$delete" ]; then
  echo "dry run; pass --delete to apply"
  exit 0
fi

# A job can check out a worktree inside its own directory. With that directory
# gone, prune drops the dead registration from the parent repository.
for gitdir in "$HOME"/git/*/*/*/.git; do
  [ -d "$gitdir" ] || continue
  git -C "${gitdir%/.git}" worktree prune
done
