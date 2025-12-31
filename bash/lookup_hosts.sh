#!/usr/bin/env bash
set -euo pipefail

# DNS lookup checker for a list of hosts.
# Uses `host` (bind-utils) when available; falls back to `getent hosts`.

# ------------------------------- Defaults ------------------------------------
DNS_SUFFIX="${DNS_SUFFIX:-}"     # e.g. "corp.example.com" (can also be set via env)
TIMEOUT="${TIMEOUT:-3}"          # seconds (for `host -W`)
RETRIES="${RETRIES:-1}"          # retries (for `host -R`)
EXIT_WITH_COUNT=false            # default: exit 0/1 (CI-friendly)

# Default host list (used when none are provided via args/file)
HOSTS_DEFAULT=(
  HDQNCNMDJ01
  HDQNCNMDS01
  HDQNCNMDS02
  HDQNCNMDTD01
  HDQNCNMDTD02
  HDQNCNMDTU01
  HDQNCNMDTU02
)

# ------------------------------- Helpers -------------------------------------
usage() {
  cat <<'EOF'
Usage:
  dns-check.sh [options] [HOST ...]
Options:
  -s SUFFIX   DNS suffix to append (only if HOST has no dot)
  -t SEC      timeout seconds for host lookup (default: 3)
  -r N        retries for host lookup (default: 1)
  -f FILE     read hosts from FILE (one per line; blanks/#comments ignored)
  -c          exit with number of failures (legacy behavior; capped to 255)
  -h          help

Env vars:
  DNS_SUFFIX, TIMEOUT, RETRIES
EOF
}

die() { printf "ERROR: %s\n" "$*" >&2; exit 2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

trim_ws() {
  # Removes all whitespace characters from the string.
  local s="$1"
  s="${s//[[:space:]]/}"
  printf "%s" "$s"
}

to_fqdn() {
  local raw="$1"
  if [[ -n "$DNS_SUFFIX" && "$raw" != *.* ]]; then
    printf "%s.%s" "$raw" "$DNS_SUFFIX"
  else
    printf "%s" "$raw"
  fi
}

lookup() {
  local raw="$1"
  local fqdn; fqdn="$(to_fqdn "$raw")"

  if have_cmd host; then
    local output
    if output="$(host -W "$TIMEOUT" -R "$RETRIES"  -t A "$fqdn" 2>&1)"; then
      printf "[OK]   %s -> %s\n" "$fqdn" "$output"
      return 0
    else
      printf "[FAIL] %s -> %s\n" "$fqdn" "$output"
      return 1
    fi
  elif have_cmd getent; then
    if getent hosts "$fqdn" >/dev/null 2>&1; then
      printf "[OK]   %s\n" "$fqdn"
      return 0
    else
      printf "[FAIL] %s -> not found via getent\n" "$fqdn"
      return 1
    fi
  else
    die "Neither 'host' nor 'getent' found in PATH"
  fi
}

# --------------------------------- Args -------------------------------------
HOST_FILE=""
while getopts ":s:t:r:f:ch" opt; do
  case "$opt" in
    s) DNS_SUFFIX="$OPTARG" ;;
    t) TIMEOUT="$OPTARG" ;;
    r) RETRIES="$OPTARG" ;;
    f) HOST_FILE="$OPTARG" ;;
    c) EXIT_WITH_COUNT=true ;;
    h) usage; exit 0 ;;
    :) die "Option -$OPTARG requires an argument" ;;
    \?) die "Unknown option: -$OPTARG (use -h for help)" ;;
  esac
done
shift $((OPTIND - 1))

# --------------------------------- Hosts ------------------------------------
HOSTS=()

if [[ -n "$HOST_FILE" ]]; then
  [[ -r "$HOST_FILE" ]] || die "Cannot read host file: $HOST_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip comments and whitespace; skip blanks
    line="${line%%#*}"
    line="$(trim_ws "$line")"
    [[ -z "$line" ]] && continue
    HOSTS+=("$line")
  done < "$HOST_FILE"
fi

if [[ "$#" -gt 0 ]]; then
  for arg in "$@"; do
    arg="$(trim_ws "$arg")"
    [[ -z "$arg" ]] && continue
    HOSTS+=("$arg")
  done
fi

if [[ "${#HOSTS[@]}" -eq 0 ]]; then
  HOSTS=("${HOSTS_DEFAULT[@]}")
fi

# --------------------------------- Main -------------------------------------
fail_count=0

for h in "${HOSTS[@]}"; do
  if ! lookup "$h"; then
    # IMPORTANT with `set -e`: avoid `((fail_count++))` (it can exit on first fail)
    fail_count=$((fail_count + 1))
  fi
done

if [[ "$fail_count" -gt 0 ]]; then
  printf "Summary: %d failed / %d total\n" "$fail_count" "${#HOSTS[@]}" >&2
else
  printf "Summary: all %d lookups OK\n" "${#HOSTS[@]}"
fi

if $EXIT_WITH_COUNT; then
  # Bash exit codes are 0-255; cap for safety
  (( fail_count > 255 )) && exit 255
  exit "$fail_count"
else
  (( fail_count > 0 )) && exit 1 || exit 0
fi
