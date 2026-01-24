#!/usr/bin/env bash
# Lists Podman containers and their attached volumes (with host mountpoints).
# Requires: podman, jq
set -euo pipefail

# Checks
command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found in PATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found in PATH. Install jq and retry (e.g. sudo dnf install jq / apt install jq)"; exit 1; }

containers_json=$(podman ps -a --format json)

if [[ $(echo "$containers_json" | jq 'length') -eq 0 ]]; then
  echo "No containers found."
  exit 0
fi

echo "Containers and attached volumes:"
echo

# Iterate containers
echo "$containers_json" \
  | jq -c '.[]' \
  | while IFS= read -r ctr; do
    id=$(echo "$ctr" | jq -r '.Id // empty')
    name=$(echo "$ctr" | jq -r '.Names[0] // empty')
    status=$(echo "$ctr" | jq -r '.Status // empty')

    printf "Container: %s\n  Name: %s\n  Status: %s\n" "$id" "$name" "$status"

    # Collect unique volume names mounted into this container
    mapfile -t volumes < <(echo "$ctr" \
      | jq -r '.Mounts[]? | select(.Type == "volume") | .Name' \
      | sort -u)

    if [[ ${#volumes[@]} -eq 0 ]]; then
      echo "  (no volumes attached)"
      echo
      continue
    fi

    for v in "${volumes[@]}"; do
      # Get mountpoint from podman volume inspect (authoritative)
      mountpoint=$(podman volume inspect "$v" --format '{{.Mountpoint}}' 2>/dev/null || true)
      # Get one or more destination paths inside the container for this volume
      dests=$(echo "$ctr" \
        | jq -r --arg vn "$v" '[.Mounts[]? | select(.Type=="volume" and .Name==$vn) | .Destination] | join(", ")')
      printf "  Volume: %s\n    Mountpoint: %s\n    Destination(s): %s\n" "$v" "${mountpoint:-(unknown)}" "${dests:-(unknown)}"
    done

    echo
  done
