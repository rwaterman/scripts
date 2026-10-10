#!/usr/bin/env bash
# Self-check for purge_state.sh. Runs it against a fake HOME with pkill, id and
# sleep stubbed, so no real Claude process or state is touched.

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd -P)/purge_state.sh"
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/purge_state_test.XXXXXX")
FAKE_ID="pstest$$"
SCRATCH="/private/tmp/claude-$FAKE_ID"
BRIDGE="/private/tmp/claude-mcp-browser-bridge-$FAKE_ID"
trap 'rm -rf "$ROOT" "$SCRATCH" "$BRIDGE"' EXIT INT TERM

fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok    $1"; else echo "  FAIL  $1 (want $3, got $2)"; fails=$((fails + 1)); fi; }
git_q() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
gone() { [ -e "$1" ] || echo gone; }
kept() { [ -e "$1" ] && echo y; }

H="$ROOT/home"; STUBS="$ROOT/stubs"; C="$H/.claude"
DESK="$H/Library/Application Support/Claude"
REPO="$H/git/host/org/repo"; WTS="$REPO/.claude/worktrees"; SIBLING="$H/git/host/org/repo-sibling"

mkdir -p "$STUBS" "$ROOT/tmp/claude-sweep" "$SCRATCH" "$BRIDGE"
printf '#!/bin/sh\necho "$*" >> "%s/pkill.log"\n' "$ROOT" > "$STUBS/pkill"
printf '#!/bin/sh\necho "%s"\n' "$FAKE_ID" > "$STUBS/id"
printf '#!/bin/sh\n' > "$STUBS/sleep"
chmod +x "$STUBS"/*
run() { env -i HOME="$H" TMPDIR="$ROOT/tmp/" PATH="$STUBS:$PATH" "$@"; }

if [ "$(run sh -c 'command -v pkill; id -u')" != "$STUBS/pkill"$'\n'"$FAKE_ID" ]; then
  echo "stubs are not in effect; stopping before anything runs" >&2
  exit 1
fi

mkdir -p "$REPO"
git init -q -b main "$REPO"
echo one > "$REPO/file.txt"
git_q "$REPO" add file.txt
git_q "$REPO" commit -qm initial

for name in clean dirty remember; do
  git_q "$REPO" worktree add -q -b "feat/$name" "$WTS/$name" main >/dev/null
done
echo unpushed >> "$WTS/clean/file.txt"
git_q "$WTS/clean" commit -qam "work with no remote anywhere"
echo change >> "$WTS/dirty/file.txt"
mkdir "$WTS/remember/.remember"; echo note > "$WTS/remember/.remember/now.md"
git_q "$REPO" worktree add -q -b feat/sibling "$SIBLING" main >/dev/null
ln -s "$SIBLING" "$WTS/link"

mkdir -p "$C/projects/p/memory" "$C/jobs/j1" "$C/plugins/cache/x" "$C/skills/s" "$H/.remember" "$REPO/.remember" \
  "$DESK/vm_bundles" "$DESK/Code Cache" "$DESK/local-agent-mode-sessions/sess" "$DESK/local-agent-mode-sessions/skills-plugin"
git_q "$REPO" worktree add -q --detach "$C/jobs/j1/wt" main >/dev/null
touch "$C/projects/p/memory/m.md" "$C/history.jsonl" "$C/settings.json" "$H/.claude.json" "$H/.claude.json.tmp.1" \
  "$H/.remember/config.json" "$H/.remember/now.md" "$DESK/Cookies" "$DESK/vm_bundles/rootfs.img"

echo "dry run:"
out=$(run "$SCRIPT")
outside=$(printf '%s\n' "$out" | sed -n 's/^would remove: *[^ ]* *//p' | grep -v -e "^$ROOT/" -e "^$SCRATCH\$" -e "^$BRIDGE\$" || true)
if [ -n "$outside" ]; then
  echo "targets outside the sandbox; stopping before --delete: $outside" >&2
  exit 1
fi
check "dry run removes nothing"          "$(kept "$C/history.jsonl")$(kept "$WTS/clean")" yy
check "dry run stops no process"         "$(gone "$ROOT/pkill.log")" gone
check "dirty worktree reported as kept"  "$(printf '%s\n' "$out" | grep -c 'would keep worktree.*/dirty$')" 1
check "refuses inside a Claude session"  "$(run env CLAUDECODE=1 "$SCRIPT" --delete >/dev/null 2>&1 || echo refused)" refused

echo "delete:"
run "$SCRIPT" --delete >/dev/null
check "processes stopped, TERM then KILL"   "$(wc -l < "$ROOT/pkill.log" | tr -d ' ')" 6
check "memory and history removed"          "$(gone "$C/projects")$(gone "$C/history.jsonl")" gonegone
check "jobs removed"                        "$(gone "$C/jobs")" gone
check "temp files removed"                  "$(gone "$SCRATCH")$(gone "$ROOT/tmp/claude-sweep")$(gone "$H/.claude.json.tmp.1")" gonegonegone
check "VM bundle removed"                   "$(gone "$DESK/vm_bundles")" gone
check "cache with a space in its name removed" "$(gone "$DESK/Code Cache")" gone
check "Desktop session data removed"        "$(gone "$DESK/local-agent-mode-sessions/sess")" gone
check "Remember history removed"            "$(gone "$H/.remember/now.md")$(gone "$REPO/.remember")" gonegone
check "Remember config kept"                "$(kept "$H/.remember/config.json")" y
check "synced skills kept"                  "$(kept "$DESK/local-agent-mode-sessions/skills-plugin")" y
check "settings, plugins and skills kept"   "$(kept "$C/settings.json")$(kept "$C/plugins/cache/x")$(kept "$C/skills/s")" yyy
check "login state kept"                    "$(kept "$H/.claude.json")$(kept "$DESK/Cookies")" yy
check "clean worktree removed"              "$(gone "$WTS/clean")" gone
check "worktree with only Remember history removed" "$(gone "$WTS/remember")" gone
check "modified worktree kept"              "$(kept "$WTS/dirty")" y
check "worktree outside .claude untouched, symlink to it not followed" "$(kept "$SIBLING/file.txt")" y
check "job worktree registration pruned"    "$(gone "$REPO/.git/worktrees/wt")" gone
check "removed worktree's commits survive on its branch" \
  "$(git_q "$REPO" log --oneline feat/clean | wc -l | tr -d ' ')" 2

echo
if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) failed"
  exit 1
fi
echo "all checks passed"
