#!/usr/bin/env bash
set -u

INTERVAL="${1:-3}"
THRESHOLD="${THRESHOLD:-75}"

RED=$'\033[31m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
BLUE=$'\033[34m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

pagesize="$(sysctl -n hw.pagesize)"
mem_bytes="$(sysctl -n hw.memsize)"

to_mb() {
  awk -v bytes="$1" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 }'
}

extract_vm_pages() {
  local key="$1"
  vm_stat | awk -F': *' -v k="$key" '$1 ~ k { gsub(/\./, "", $2); print $2 }'
}

get_os_pressure_percent() {
  # Uses the built-in memory_pressure command if available.
  # We invert "free percentage" into a pressure-like percentage.
  local free_pct
  free_pct="$(memory_pressure 2>/dev/null | awk -F': *' '
    /System-wide memory free percentage/ {
      gsub(/%/, "", $2)
      print $2
      exit
    }'
  )"

  if [[ -n "${free_pct:-}" && "$free_pct" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    awk -v f="$free_pct" 'BEGIN { printf "%.0f", 100 - f }'
    return 0
  fi

  return 1
}

bar() {
  local pct="$1"
  local width="${2:-32}"
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))

  printf "["
  for ((i=0; i<filled; i++)); do printf "█"; done
  for ((i=0; i<empty; i++)); do printf " "; done
  printf "]"
}

pick_color() {
  local pct="$1"
  if (( pct >= THRESHOLD )); then
    printf "%s" "$RED"
  elif (( pct >= 60 )); then
    printf "%s" "$YELLOW"
  else
    printf "%s" "$GREEN"
  fi
}

last_pageouts=""
last_swap_used_mb=""

while true; do
  free_pages="$(extract_vm_pages 'Pages free')"
  active_pages="$(extract_vm_pages 'Pages active')"
  inactive_pages="$(extract_vm_pages 'Pages inactive')"
  speculative_pages="$(extract_vm_pages 'Pages speculative')"
  wired_pages="$(extract_vm_pages 'Pages wired down')"
  compressor_pages="$(extract_vm_pages 'Pages occupied by compressor')"
  pageouts="$(vm_stat | awk -F': *' '/Pageouts/ { gsub(/\./, "", $2); print $2; exit }')"

  free_bytes=$(( free_pages * pagesize ))
  active_bytes=$(( active_pages * pagesize ))
  inactive_bytes=$(( inactive_pages * pagesize ))
  speculative_bytes=$(( speculative_pages * pagesize ))
  wired_bytes=$(( wired_pages * pagesize ))
  compressor_bytes=$(( compressor_pages * pagesize ))

  reclaimable_bytes=$(( inactive_bytes + speculative_bytes ))
  non_reclaimable_bytes=$(( active_bytes + wired_bytes + compressor_bytes ))
  non_reclaimable_pct="$(awk -v used="$non_reclaimable_bytes" -v total="$mem_bytes" 'BEGIN { printf "%.0f", (used / total) * 100 }')"

  if os_pressure_pct="$(get_os_pressure_percent)"; then
    headline_pct="$os_pressure_pct"
    headline_label="macOS Memory Pressure"
  else
    headline_pct="$non_reclaimable_pct"
    headline_label="Estimated Memory Pressure"
  fi

  color="$(pick_color "$headline_pct")"

  swap_used_raw="$(sysctl vm.swapusage 2>/dev/null | awk -F'used = | free =' '{print $2}' | awk '{print $1}')"
  swap_used_mb="$(
    awk -v s="${swap_used_raw:-0M}" '
      BEGIN {
        gsub(/[[:space:]]/, "", s)
        if (s ~ /G$/) { sub(/G$/, "", s); printf "%.0f", s * 1024 }
        else if (s ~ /M$/) { sub(/M$/, "", s); printf "%.0f", s }
        else if (s ~ /K$/) { sub(/K$/, "", s); printf "%.0f", s / 1024 }
        else { printf "%.0f", s }
      }'
  )"

  if [[ -n "${last_pageouts:-}" ]]; then
    pageouts_delta=$(( pageouts - last_pageouts ))
  else
    pageouts_delta=0
  fi

  if [[ -n "${last_swap_used_mb:-}" ]]; then
    swap_delta_mb=$(( swap_used_mb - last_swap_used_mb ))
  else
    swap_delta_mb=0
  fi

  last_pageouts="$pageouts"
  last_swap_used_mb="$swap_used_mb"

  clear
  printf "%smacOS Memory Watch%s\n\n" "$BOLD" "$RESET"

  printf "%-24s %8s MB\n" "Physical RAM:"       "$(to_mb "$mem_bytes")"
  printf "%-24s %8s MB\n" "App/Active:"         "$(to_mb "$active_bytes")"
  printf "%-24s %8s MB\n" "Wired:"              "$(to_mb "$wired_bytes")"
  printf "%-24s %8s MB\n" "Compressed:"         "$(to_mb "$compressor_bytes")"
  printf "%-24s %8s MB\n" "Reclaimable Cache:"  "$(to_mb "$reclaimable_bytes")"
  printf "%-24s %8s MB\n" "Free:"               "$(to_mb "$free_bytes")"
  printf "%-24s %8s MB\n" "Swap Used:"          "$swap_used_mb"
  printf "%-24s %8s\n"    "Pageouts:"           "$pageouts"
  printf "%-24s %8s / tick\n" "Swap Growth:"    "${swap_delta_mb} MB"
  printf "%-24s %8s / tick\n" "New Pageouts:"   "$pageouts_delta"

  printf "\n%-24s " "$headline_label:"
  printf "%s" "$color"
  bar "$headline_pct" 36
  printf " %3s%%%s\n" "$headline_pct" "$RESET"

  printf "%-24s " "Non-Reclaimable Memory:"
  printf "%s" "$BLUE"
  bar "$non_reclaimable_pct" 36
  printf " %3s%%%s\n" "$non_reclaimable_pct" "$RESET"

  printf "\n%sGreen%s < 60%%   %sYellow%s 60-74%%   %sRed%s >= %s%s%%%s\n" \
    "$GREEN" "$RESET" \
    "$YELLOW" "$RESET" \
    "$RED" "$RESET" \
    "$BOLD" "$THRESHOLD" "$RESET"

  printf "%sOS pressure%s = built-in estimate when available\n" "$DIM" "$RESET"
  printf "%sNon-reclaimable%s = active + wired + compressed\n" "$DIM" "$RESET"
  printf "%sRefresh%s every %ss\n" "$DIM" "$RESET" "$INTERVAL"

  sleep "$INTERVAL"
done
