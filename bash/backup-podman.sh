#!/usr/bin/env bash
# Comprehensive Podman backup: containers, volumes, quadlets, configs
set -euo pipefail

# === Configuration ===
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/containers/podman-backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/backup-$TIMESTAMP"
SAVE_IMAGES="${SAVE_IMAGES:-no}"  # Set to "yes" to export image tarballs (can be large)
BACKUP_ROOTFUL="${BACKUP_ROOTFUL:-yes}"  # Set to "no" to skip rootful containers

# === Checks ===
command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found"; exit 1; }

# Check if we can backup rootful containers
CAN_BACKUP_ROOTFUL=false
if [[ "$BACKUP_ROOTFUL" == "yes" ]] && sudo -n podman version &>/dev/null; then
  CAN_BACKUP_ROOTFUL=true
elif [[ "$BACKUP_ROOTFUL" == "yes" ]] && sudo -v &>/dev/null && sudo podman version &>/dev/null; then
  CAN_BACKUP_ROOTFUL=true
fi

echo "=== Podman Backup ==="
echo "Backup directory: $BACKUP_DIR"
echo "Rootless backup: YES"
echo "Rootful backup: $([[ "$CAN_BACKUP_ROOTFUL" == "true" ]] && echo "YES" || echo "NO (requires sudo)")"
mkdir -p "$BACKUP_DIR"

# === Backup Function ===
# Handles backing up containers, volumes, networks, images for a given context
# Args: $1=context_name (rootless/rootful), $2=podman_cmd (podman or "sudo podman")
backup_podman_context() {
  local context="$1"
  local podman_cmd="$2"
  local base_dir="$BACKUP_DIR/$context"
  
  echo
  echo "=== Backing up $context containers ==="
  mkdir -p "$base_dir"
  
  # 1. System Info
  echo "  [1/5] Capturing system info..."
  {
    echo "Context: $context"
    echo "Backup date: $(date -Iseconds)"
    echo "Hostname: $(hostname)"
    echo "Podman version: $($podman_cmd --version)"
    $podman_cmd info --format json
  } > "$base_dir/system-info.json"
  
  # 2. Container Metadata
  echo "  [2/5] Backing up container metadata..."
  mkdir -p "$base_dir/containers"
  $podman_cmd ps -a --format json > "$base_dir/containers/containers.json"
  
  # Individual inspect files for each container
  local container_count
  container_count=$($podman_cmd ps -aq 2>/dev/null | wc -l)
  if [[ $container_count -gt 0 ]]; then
    while IFS= read -r cid; do
      local cname
      cname=$($podman_cmd inspect "$cid" --format '{{.Name}}' | sed 's/^\///')
      $podman_cmd inspect "$cid" > "$base_dir/containers/${cname}-${cid:0:12}.json"
    done < <($podman_cmd ps -aq)
    echo "    Saved metadata for $container_count containers"
  else
    echo "    No containers found"
  fi
  
  # 3. Volumes (data)
  echo "  [3/5] Backing up volumes..."
  mkdir -p "$base_dir/volumes"
  
  local volume_count
  volume_count=$($podman_cmd volume ls -q 2>/dev/null | wc -l)
  if [[ $volume_count -gt 0 ]]; then
    while IFS= read -r vol; do
      echo "    Backing up volume: $vol"
      # Get volume mountpoint
      local mountpoint
      mountpoint=$($podman_cmd volume inspect "$vol" --format '{{.Mountpoint}}')
      
      # Tar the volume data (preserve permissions, xattrs)
      if [[ "$context" == "rootful" ]]; then
        # For rootful, use sudo tar
        sudo tar -czf "$base_dir/volumes/${vol}.tar.gz" \
          -C "$(dirname "$mountpoint")" \
          "$(basename "$mountpoint")" \
          2>/dev/null || {
            echo "      WARNING: Could not backup $vol directly. Trying with podman run..."
            $podman_cmd run --rm \
              -v "$vol:/volume:ro" \
              -v "$base_dir/volumes:/backup:rw" \
              alpine:latest \
              tar -czf "/backup/${vol}.tar.gz" -C /volume .
          }
      else
        # For rootless, regular tar should work
        tar -czf "$base_dir/volumes/${vol}.tar.gz" \
          -C "$(dirname "$mountpoint")" \
          "$(basename "$mountpoint")" \
          2>/dev/null || {
            echo "      WARNING: Could not backup $vol directly. Trying with podman run..."
            $podman_cmd run --rm \
              -v "$vol:/volume:ro" \
              -v "$base_dir/volumes:/backup:rw" \
              alpine:latest \
              tar -czf "/backup/${vol}.tar.gz" -C /volume .
          }
      fi
      
      # Save volume metadata
      $podman_cmd volume inspect "$vol" > "$base_dir/volumes/${vol}.json"
    done < <($podman_cmd volume ls -q)
    echo "    Saved $volume_count volumes"
  else
    echo "    No volumes found"
  fi
  
  # 4. Networks
  echo "  [4/5] Backing up networks..."
  mkdir -p "$base_dir/networks"
  $podman_cmd network ls --format json > "$base_dir/networks/networks.json"
  
  while IFS= read -r net; do
    # Skip default podman network
    [[ "$net" == "podman" ]] && continue
    $podman_cmd network inspect "$net" > "$base_dir/networks/${net}.json" 2>/dev/null || true
  done < <($podman_cmd network ls --format '{{.Name}}')
  echo "    Saved network configs"
  
  # 5. Images (optional)
  echo "  [5/5] Handling images..."
  mkdir -p "$base_dir/images"
  $podman_cmd images --format json > "$base_dir/images/images.json"
  
  if [[ "$SAVE_IMAGES" == "yes" ]]; then
    echo "    Exporting image tarballs (this may take a while)..."
    while IFS= read -r img_id; do
      local img_name
      img_name=$($podman_cmd inspect "$img_id" --format '{{index .RepoTags 0}}' | tr '/:' '_')
      [[ -z "$img_name" || "$img_name" == "<none>" ]] && img_name="image-${img_id:0:12}"
      echo "      Saving $img_name"
      $podman_cmd save "$img_id" -o "$base_dir/images/${img_name}.tar"
    done < <($podman_cmd images -q)
  else
    echo "    Skipping image export (set SAVE_IMAGES=yes to enable)"
  fi
}

# === Backup Rootless Containers ===
backup_podman_context "rootless" "podman"

# === Backup Rootful Containers ===
if [[ "$CAN_BACKUP_ROOTFUL" == "true" ]]; then
  backup_podman_context "rootful" "sudo podman"
else
  echo
  echo "=== Skipping rootful containers ==="
  echo "  (Run with sudo or ensure passwordless sudo for podman to include rootful)"
fi

# === Quadlets (systemd units) ===
echo
echo "=== Backing up quadlet files ==="
mkdir -p "$BACKUP_DIR/quadlets"

# Possible quadlet locations (rootless and rootful)
quadlet_dirs=(
  "$HOME/.config/containers/systemd"
  "/etc/containers/systemd"
  "/usr/share/containers/systemd"
)

found_quadlets=0
for qdir in "${quadlet_dirs[@]}"; do
  if [[ -d "$qdir" ]]; then
    echo "  Checking $qdir"
    # Copy .container, .volume, .network, .kube, .image files
    if [[ "$qdir" == "/etc/"* ]] || [[ "$qdir" == "/usr/"* ]]; then
      # Use sudo for system directories
      sudo find "$qdir" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) \
        -exec sudo cp --parents {} "$BACKUP_DIR/quadlets/" \; 2>/dev/null || true
      count=$(sudo find "$qdir" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) 2>/dev/null | wc -l)
    else
      # Regular user directories
      find "$qdir" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) \
        -exec cp --parents {} "$BACKUP_DIR/quadlets/" \; 2>/dev/null || true
      count=$(find "$qdir" -type f \( -name "*.container" -o -name "*.volume" -o -name "*.network" -o -name "*.kube" -o -name "*.image" \) 2>/dev/null | wc -l)
    fi
    found_quadlets=$((found_quadlets + count))
  fi
done

if [[ $found_quadlets -gt 0 ]]; then
  echo "  Saved $found_quadlets quadlet file(s)"
else
  echo "  No quadlet files found"
fi

# === Podman config files ===
echo
echo "=== Backing up Podman config files ==="
mkdir -p "$BACKUP_DIR/configs"

config_files=(
  "$HOME/.config/containers/containers.conf"
  "$HOME/.config/containers/storage.conf"
  "$HOME/.config/containers/registries.conf"
  "$HOME/.config/containers/policy.json"
  "/etc/containers/containers.conf"
  "/etc/containers/storage.conf"
  "/etc/containers/registries.conf"
  "/etc/containers/policy.json"
)

for cf in "${config_files[@]}"; do
  if [[ -f "$cf" ]]; then
    if [[ "$cf" == "/etc/"* ]]; then
      # Use sudo for system config files
      sudo cp --parents "$cf" "$BACKUP_DIR/configs/" 2>/dev/null || true
    else
      cp --parents "$cf" "$BACKUP_DIR/configs/" 2>/dev/null || true
    fi
  fi
done
echo "  Config files saved"

# === Create backup manifest ===
rootless_containers=$(podman ps -aq 2>/dev/null | wc -l)
rootless_volumes=$(podman volume ls -q 2>/dev/null | wc -l)
rootless_images=$(podman images -q 2>/dev/null | wc -l)

if [[ "$CAN_BACKUP_ROOTFUL" == "true" ]]; then
  rootful_containers=$(sudo podman ps -aq 2>/dev/null | wc -l)
  rootful_volumes=$(sudo podman volume ls -q 2>/dev/null | wc -l)
  rootful_images=$(sudo podman images -q 2>/dev/null | wc -l)
else
  rootful_containers=0
  rootful_volumes=0
  rootful_images=0
fi

cat > "$BACKUP_DIR/MANIFEST.txt" <<EOF
Podman Backup Manifest
======================
Created: $(date -Iseconds)
Hostname: $(hostname)
Podman Version: $(podman --version)

Backup Contents:
- rootless/: Rootless containers, volumes, networks, images
- rootful/: Rootful containers, volumes, networks, images (if backed up)
- quadlets/: Systemd quadlet unit files
- configs/: Podman configuration files

Rootless Resources:
  Containers: $rootless_containers
  Volumes: $rootless_volumes
  Images: $rootless_images

Rootful Resources:
  Containers: $rootful_containers
  Volumes: $rootful_volumes
  Images: $rootful_images
  Status: $([[ "$CAN_BACKUP_ROOTFUL" == "true" ]] && echo "BACKED UP" || echo "NOT BACKED UP (requires sudo)")
EOF

echo
echo "=== Backup Complete ==="
echo "Location: $BACKUP_DIR"
echo
echo "Summary:"
echo "  Rootless containers: $rootless_containers"
echo "  Rootful containers: $rootful_containers $([[ "$CAN_BACKUP_ROOTFUL" == "true" ]] || echo "(not backed up)")"
echo
echo "To restore on a new system, copy this directory and run: ./restore-podman.sh $BACKUP_DIR"
echo
du -sh "$BACKUP_DIR"