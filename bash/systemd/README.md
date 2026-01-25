# Podman Backup Systemd Timers

Automated backup timers for Podman containers with different backup modes.

## Installation

### For User (Rootless) Timers

```bash
# Create user systemd directory if it doesn't exist
mkdir -p ~/.config/systemd/user/

# Copy timer files
cp podman-backup-daily.service ~/.config/systemd/user/
cp podman-backup-daily.timer ~/.config/systemd/user/
cp podman-backup-weekly.service ~/.config/systemd/user/
cp podman-backup-weekly.timer ~/.config/systemd/user/

# Reload systemd
systemctl --user daemon-reload

# Enable and start timers
systemctl --user enable --now podman-backup-daily.timer
systemctl --user enable --now podman-backup-weekly.timer

# Enable lingering (allows user services to run when not logged in)
sudo loginctl enable-linger $USER
```

### For System (Rootful) Timers

```bash
# Copy to system directory
sudo cp podman-backup-daily.service /etc/systemd/system/
sudo cp podman-backup-daily.timer /etc/systemd/system/
sudo cp podman-backup-weekly.service /etc/systemd/system/
sudo cp podman-backup-weekly.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start timers
sudo systemctl enable --now podman-backup-daily.timer
sudo systemctl enable --now podman-backup-weekly.timer
```

## Management Commands

### Check Timer Status

```bash
# User timers
systemctl --user list-timers podman-backup-*

# System timers
sudo systemctl list-timers podman-backup-*
```

### View Timer Details

```bash
# Check when next run is scheduled
systemctl --user status podman-backup-daily.timer
systemctl --user status podman-backup-weekly.timer
```

### View Backup Logs

```bash
# User backups
journalctl --user -u podman-backup-daily.service
journalctl --user -u podman-backup-weekly.service

# System backups
sudo journalctl -u podman-backup-daily.service
sudo journalctl -u podman-backup-weekly.service

# Follow live
journalctl --user -u podman-backup-weekly.service -f
```

### Manual Trigger

```bash
# Trigger a backup manually
systemctl --user start podman-backup-daily.service
systemctl --user start podman-backup-weekly.service

# Or run the script directly
/home/rhlabs/my_work_tools/bin/bash/backup-podman.sh --mode daily
/home/rhlabs/my_work_tools/bin/bash/backup-podman.sh --mode weekly
```

### Disable/Stop Timers

```bash
# User timers
systemctl --user disable --now podman-backup-daily.timer
systemctl --user disable --now podman-backup-weekly.timer

# System timers
sudo systemctl disable --now podman-backup-daily.timer
sudo systemctl disable --now podman-backup-weekly.timer
```

## Backup Schedules

- **Daily Backup**: Runs at 2:00 AM every day
  - Mode: `daily` (metadata only, no volumes)
  - Duration: ~1-5 minutes
  - Size: ~few MB
  
- **Weekly Backup**: Runs at 3:00 AM every Sunday
  - Mode: `weekly` (full backup with volumes)
  - Duration: ~2-6 hours (depending on volume size)
  - Size: ~GB (depending on data)

## Customization

Edit the `.service` files to:
- Change backup destination: Add `-d /path/to/backups` to `ExecStart`
- Skip rootful containers: Add `--no-rootful` to `ExecStart`
- Adjust timeout: Modify `TimeoutStartSec`

Edit the `.timer` files to:
- Change schedule: Modify `OnCalendar`
- Adjust randomized delay: Modify `RandomizedDelaySec`

Example custom service file:
```ini
ExecStart=/home/rhlabs/my_work_tools/bin/bash/backup-podman.sh --mode weekly -d /mnt/nas/backups
```

## Backup Retention

Consider adding a cleanup script to remove old backups:

```bash
# Keep last 7 daily backups
find /home/rhlabs/containers/podman-backups/daily-* -maxdepth 0 -mtime +7 -exec rm -rf {} \;

# Keep last 4 weekly backups
find /home/rhlabs/containers/podman-backups/weekly-* -maxdepth 0 -mtime +28 -exec rm -rf {} \;
```

Add this to a cron job or another systemd timer.

## Troubleshooting

### Timer not running
```bash
# Check if timer is active
systemctl --user is-active podman-backup-daily.timer

# Check for errors
systemctl --user status podman-backup-daily.timer
journalctl --user -xe
```

### User service stops after logout
```bash
# Enable lingering
sudo loginctl enable-linger $USER
loginctl show-user $USER | grep Linger
```

### Permission issues with rootful backups
- Ensure passwordless sudo for podman is configured
- Or run as system service (not user service)

## See Also

- Main backup script: `backup-podman.sh --help`
- Systemd timer documentation: `man systemd.timer`
- Journalctl documentation: `man journalctl`
