#!/usr/bin/env bash
# Restore Podman containers, volumes, quadlets from backup
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup-directory> [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  --rootless-only    Restore only rootless containers"
  echo "  --rootful-only     Restore only rootful containers"
  echo
  echo "Example: $0 ~/podman-backups/full-20260124-120000"
  exit 1
fi

BACKUP_DIR="$1"
shift

# Parse options
RESTORE_ROOTLESS=true
RESTORE_ROOTFUL=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --rootless-only)
      RESTORE_ROOTFUL=false
      shift
      ;;
    --rootful-only)
      RESTORE_ROOTLESS=false
      shift
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "ERROR: Backup directory not found: $BACKUP_DIR"
  exit 1
fi

command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found"; exit 1; }

echo "=== Podman Restore ==="
echo "Source: $BACKUP_DIR"
echo

# Check manifest
if [[ -f "$BACKUP_DIR/MANIFEST.txt" ]]; then
  echo "Backup manifest:"
  cat "$BACKUP_DIR/MANIFEST.txt"
  echo
  read -p "Proceed with restore? (yes/no): " confirm
  [[ "$confirm" != "yes" ]] && { echo "Restore cancelled."; exit 0; }
fi

# === 1. Restore config files ===
echo
echo "[1/6] Restoring Podman config files..."
if [[ -d "$BACKUP_DIR/configs" ]]; then
  # User config files
  if [[ -d "$BACKUP_DIR/configs/home" ]] || [[ -d "$BACKUP_DIR/configs/$USER" ]]; then
    echo "  Restoring user config files..."
    for conf_dir in "$BACKUP_DIR/configs/home/"* "$BACKUP_DIR/configs/$USER"; do
      [[ -d "$conf_dir" ]] || continue
      user_config_base="$conf_dir/.config/containers"
      if [[ -d "$user_config_base" ]]; then
        mkdir -p "$HOME/.config/containers"
        cp -rp "$user_config_base/"* "$HOME/.config/containers/" 2>/dev/null || true
      fi
    done
  fi
  
  # SyRestore function for a context ===
restore_context() {
  local context="$1"
  local podman_cmd="$2"
  local base_dir="$BACKUP_DIR/$context"
  
  [[ ! -d "$base_dir" ]] && return
  
  echo
  echo "=== Restoring $context containers ==="
  
  # 2. Networks
  echo "  [2/6] Restoring networks..."
  if [[ -d "$base_dir/networks" ]]; then
    for netfile in "$base_dir/networks"/*.json; do
      [[ "$netfile" == */networks.json ]] && continue
      [[ -f "$netfile" ]] || continue
      
      netname=$(basename "$netfile" .json)
      echo "    Creating network: $netname"
      
      subnet=$(jq -r '.[0].subnets[0].subnet // empty' "$netfile")
      gateway=$(jq -r '.[0].subnets[0].gateway // empty' "$netfile")
      driver=$(jq -r '.[0].driver // "bridge"' "$netfile")
      
      if $podman_cmd network exists "$netname" 2>/dev/null; then
        echo "      Network $netname already exists, skipping"
      else
        cmd="$podman_cmd network create"
        [[ -n "$driver" ]] && cmd="$cmd --driver $driver"
        [[ -n "$subnet" ]] && cmd="$cmd --subnet $subnet"
  # 3. Volumes
  echo "  [3/6] Restoring volumes..."
  if [[ -d "$base_dir/volumes" ]] && ls "$base_dir/volumes"/*.tar.gz >/dev/null 2>&1; then
    for voltgz in "$base_dir/volumes"/*.tar.gz; do
      [[ -f "$voltgz" ]] || continue
      volname=$(basename "$voltgz" .tar.gz)
      echo "    Restoring volume: $volname"
      
      # Create volume if it doesn't exist
      if ! $podman_cmd volume exists "$volname" 2>/dev/null; then
        $podman_cmd volume create "$volname"
      else
        echo "      Volume $volname already exists; will overwrite data"
      fi
      
      # Get volume mountpoint
      mountpoint=$($podman_cmd volume inspect "$volname" --format '{{.Mountpoint}}')
      
      # Extract data into volume
      if [[ "$context" == "rootful" ]]; then
        # Use sudo for rootful volumes
        if sudo tar -xzf "$voltgz" -C "$(dirname "$mountpoint")" 2>/dev/null; then
          echo "      Extracted directly to $mountpoint"
        else
          echo "      Using container fallback..."
          $podman_cmd run --rm \
            -v "$volname:/volume:rw" \
            -v "$(dirname "$voltgz"):/backup:ro" \
            alpine:latest \
            sh -c "tar -xzf /backup/$(basename "$voltgz") -C /volume"
        fi
      else
        # Use podman unshare for rootless volumes
        if podman unshare tar -xzf "$voltgz" -C "$(dirname "$mountpoint")" 2>/dev/null; then
          echo "      Extracted directly to $mountpoint"
        else
          echo "      Using container fallback..."
          $podman_cmd run --rm \
            -v "$volname:/volume:rw" \
  # 4. Images
  echo "  [4/6] Restoring images..."
  if [[ -d "$base_dir/images" ]] && ls "$base_dir/images"/*.tar >/dev/null 2>&1; then
    for imgtgz in "$base_dir/images"/*.tar; do
      [[ -f "$imgtgz" ]] || continue
      echo "    Loading image: $(basename "$imgtgz")"
      $podman_cmd load -i "$imgtgz"
    done
  else
    echo "    No image tarballs found"
    if [[ -f "$base_dir/images/images.json" ]]; then
      echo "    Images to pull manually:"
      jq -r '.[] | select(.Repository != "<none>") | "      " + .Repository + ":" + .Tag' "$base_dir/images/images.json" | head -5
    fi
  fi
} Restore rootless context
if [[ "$RESTORE_ROOTLESS" == "true" ]]; then
  restore_context "rootless" "podman"
fi

# Restore rootful context
if [[ "$RESTORE_ROOTFUL" == "true" ]]; then
  if sudo -n podman version &>/dev/null || sudo -v &>/dev/null; then
    restore_context "rootful" "sudo podman"
  else
    echo
    echo "=== Skipping rootful restore (requires sudo) ==="
  fi
fi

# === 5. Restore quadlets ===
echo
echo "[5/6] Restoring quadlet files..."
if [[ -d "$BACKUP_DIR/quadlets" ]]; then
  restored_count=0
  
  # Restore user quadlets (if exists)
  if [[ -d "$BACKUP_DIR/quadlets/home" ]] || [[ -d "$BACKUP_DIR/quadlets/$USER" ]]; then
    echo "  Restoring user quadlets..."
    user_quadlet_dir="$HOME/.config/containers/systemd"
    mkdir -p "$user_quadlet_dir"
    
    for quadlet_base in "$BACKUP_DIR/quadlets/home/"*"/.config/containers/systemd" "$BACKUP_DIR/quadlets/$USER/.config/containers/systemd"; do
      if [[ -d "$quadlet_base" ]]; then
        cp -r "$quadlet_base/"* "$user_quadlet_dir/" 2>/dev/null || true
        count=$(find "$quadlet_base" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) 2>/dev/null | wc -l)
        restored_count=$((restored_count + count))
      fi
    do[6/6] Restore summary"
echo
echo "=== Restore Complete ==="
echo "Source: $BACKUP_DIR"
echo
echo "Next steps:"
echo "1. Verify volumes:   podman volume ls   (and/or sudo podman volume ls)"
echo "2. Verify networks:  podman network ls  (and/or sudo podman network ls)"
echo "3. Start quadlets:"
echo "   - User:   systemctl --user start <service-name>"
echo "   - System: sudo systemctl start <service-name>"
echo "4. Or manually recreate containers using metadata in:"
echo "   $BACKUP_DIR/rootless/containers/*.json"
echo "   $BACKUP_DIR/rootful/containers/*.json"
echo
echo "NOTE: Containers are NOT automatically started."
echo "      Quadlet services must be started manuallyner" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) 2>/dev/null | wc -l)
    restored_count=$((restored_count + count))
  fi
  
  if [[ -d "$BACKUP_DIR/quadlets/usr/share/containers/systemd" ]]; then
    echo "  Restoring shared quadlets (requires sudo)..."
    sudo mkdir -p /usr/share/containers/systemd
    sudo cp -r "$BACKUP_DIR/quadlets/usr/share/containers/systemd/"* /usr/share/containers/systemd/ 2>/dev/null || true
    count=$(sudo find "$BACKUP_DIR/quadlets/usr/share/containers/systemd" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) 2>/dev/null | wc -l)
    restored_count=$((restored_count + count))
  fi
  
  echo "  Restored $restored_count quadlet file(s)"
  
  # Reload systemd
  echo "  Reloading systemd daemon..."
  systemctl --user daemon-reload 2>/dev/null || true
  sudo systemctl daemon-reload 2>/dev/null || true
  done
else
  echo "  No image tarballs found. Pull images manually or from quadlets:"
  if [[ -f "$BACKUP_DIR/images/images.json" ]]; then
    jq -r '.[] | select(.Repository != "<none>") | .Repository + ":" + .Tag' "$BACKUP_DIR/images/images.json" | head -10
  fi
fi

# === 5. Restore quadlets ===
echo "[5/5] Restoring quadlet files..."
if [[ -d "$BACKUP_DIR/quadlets" ]]; then
  # Determine target directory (rootless vs rootful)
  if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ $(id -u) -ne 0 ]]; then
    QUADLET_DIR="$HOME/.config/containers/systemd"
  else
    QUADLET_DIR="/etc/containers/systemd"
  fi
  
  echo "  Target quadlet dir: $QUADLET_DIR"
  mkdir -p "$QUADLET_DIR"
  
  # Copy quadlet files
  find "$BACKUP_DIR/quadlets" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) \
    -exec cp {} "$QUADLET_DIR/" \;
  
  count=$(find "$BACKUP_DIR/quadlets" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) 2>/dev/null | wc -l)
  echo "  Restored $count quadlet file(s)"
  
  # Reload systemd
  echo "  Reloading systemd daemon..."
  systemctl --user daemon-reload 2>/dev/null || sudo systemctl daemon-reload
  
  echo
  echo "  To start quadlet services:"
  echo "    systemctl --user start <service-name>   (rootless)"
  echo "    sudo systemctl start <service-name>     (rootful)"
else
  echo "  No quadlets to restore"
fi

echo
echo "=== Restore Complete ==="
echo
echo "Next steps:"
echo "1. Verify volumes:   podman volume ls"
echo "2. Start quadlets:   systemctl --user start <service>"
echo "3. Or manually recreate containers using metadata in:"
echo "   $BACKUP_DIR/containers/*.json"
echo
echo "NOTE: Containers are NOT automatically started. Use quadlets or 'podman run' to recreate."