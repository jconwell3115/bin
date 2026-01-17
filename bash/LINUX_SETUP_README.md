# RHEL/Fedora Linux Setup Script Usage Guide

## Overview

This script provides automated setup and hardening for **RHEL** and **Fedora** Linux distributions. It automatically detects your distro, installs appropriate repositories, hardens system security, and sets up a complete development environment with VSCode.

## Quick Start

~~~bash
# Download the script directly
wget https://raw.githubusercontent.com/jconwell3115/bin/roadhouse/bash/rhel-fedora-setup.sh

# Make it executable
chmod +x rhel-fedora-setup.sh

# Run as root
sudo ./rhel-fedora-setup.sh
~~~

## Alternative: Clone from Repository

~~~bash
# Clone your bin repository
git clone https://github.com/jconwell3115/bin.git

# Navigate to the bash directory
cd bin/bash

# Make the script executable
chmod +x rhel-fedora-setup.sh

# Execute the script
sudo ./rhel-fedora-setup.sh
~~~

## Interactive Setup Process

When you run the script, it will:

1. **Detect your distribution automatically**
   ~~~bash
   [INFO] Detecting Linux distribution...
   [INFO] Detected: Fedora 41
   ~~~

2. **Prompt for confirmation or manual selection**
   ~~~bash
   [INPUT] Select your distribution:
   1) Fedora
   2) RHEL (Red Hat Enterprise Linux)
   
   Enter choice [1-2] (detected: fedora):
   ~~~
   - Press **Enter** to accept the detected distribution
   - Or type **1** for Fedora or **2** for RHEL to override

3. **Proceed with installation and hardening**

## What This Script Does

### 🔍 Distribution Detection
- ✅ Automatically detects **Fedora** or **RHEL**
- ✅ Interactive prompt to confirm or override detection
- ✅ Graceful handling of unsupported distributions

### 📦 Repository Setup

**For RHEL:**
- ✅ Installs **EPEL** repository
- ✅ Enables **CRB/PowerTools** repository
- ✅ Imports **Microsoft GPG key**
- ✅ Adds **VSCode** repository
- ✅ Adds **Flathub** for Flatpak apps

**For Fedora:**
- ✅ Installs **RPM Fusion** (free + nonfree)
- ✅ Imports **Microsoft GPG key**
- ✅ Adds **VSCode** repository
- ✅ Adds **Flathub** for Flatpak apps

### 🔒 Security Hardening
- ✅ Enables and configures **firewalld**
- ✅ Ensures **SELinux** is in enforcing mode
- ✅ Installs and configures **fail2ban** for SSH protection
- ✅ Sets strong **password policies** (14+ chars, mixed case, numbers, symbols)
- ✅ Enables **automatic security updates**
- ✅ Applies **kernel hardening** parameters
- ✅ Disables **core dumps**
- ✅ Initializes **AIDE** for file integrity monitoring
- ✅ Disables unnecessary services
- ✅ Sets secure **umask** (027)

### 🛠️ Software Installation
- ✅ **Visual Studio Code** with Microsoft GPG verification
- ✅ **Flatpak** with Flathub repository
- ✅ Essential development tools:
  - git
  - wget, curl
  - vim
  - htop
  - tmux
  - unzip, tar, bzip2
  - neofetch

### 📋 Security Audit Log
- ✅ Creates timestamped log in `/root/security-setup-YYYYMMDD-HHMMSS.log`
- ✅ Documents all changes made to the system
- ✅ Provides next steps and recommendations

## Post-Installation Commands

### Verify VSCode Installation
~~~bash
code --version
~~~

### Check System Information
~~~bash
neofetch
~~~

### Check Firewall Status
~~~bash
sudo firewall-cmd --list-all
~~~

### Monitor Fail2ban
~~~bash
# Check SSH jail status
sudo fail2ban-client status sshd

# View banned IPs
sudo fail2ban-client status sshd | grep "Banned IP"
~~~

### Run File Integrity Check
~~~bash
# Check for file system changes
sudo aide --check

# Update AIDE database after legitimate changes
sudo aide --update
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
~~~

### Flatpak Commands
~~~bash
# Search for applications
flatpak search firefox

# Install an application
flatpak install flathub org.mozilla.firefox

# List installed Flatpak apps
flatpak list

# Update all Flatpak apps
flatpak update

# Remove an application
flatpak uninstall org.mozilla.firefox
~~~

## Additional Hardening Recommendations

After running this script, consider implementing these additional security measures:

### 1. SSH Hardening

Edit `/etc/ssh/sshd_config`:
~~~bash
sudo vim /etc/ssh/sshd_config
~~~

Add or modify these settings:
~~~bash
# Disable root login
PermitRootLogin no

# Disable password authentication (use SSH keys only)
PasswordAuthentication no

# Enable public key authentication
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Limit authentication attempts
MaxAuthTries 3

# Set idle timeout (5 minutes)
ClientAliveInterval 300
ClientAliveCountMax 0
~~~

Restart SSH service:
~~~bash
sudo systemctl restart sshd
~~~

### 2. Setup SSH Key Authentication

On your local machine:
~~~bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to server
ssh-copy-id username@server-ip
~~~

### 3. Configure Automated AIDE Checks

Create a daily cron job:
~~~bash
sudo crontab -e
~~~

Add this line:
~~~bash
0 2 * * * /usr/sbin/aide --check | mail -s "AIDE Report" root@localhost
~~~

### 4. Review and Customize Fail2ban

Check fail2ban configuration:
~~~bash
sudo cat /etc/fail2ban/jail.local
~~~

Customize settings as needed:
~~~bash
sudo vim /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
~~~

### 5. Monitor System Logs

View recent authentication attempts:
~~~bash
sudo journalctl -u sshd -n 50
~~~

View firewall logs:
~~~bash
sudo journalctl -u firewalld -f
~~~

### 6. Setup Regular Backups

Consider using:
- **rsync** for local backups
- **Borg** or **restic** for encrypted backups
- **Timeshift** for system snapshots (Fedora with btrfs)

## Kernel Hardening Parameters Applied

The script applies these kernel parameters via `/etc/sysctl.d/99-security-hardening.conf`:

~~~bash
# Kernel hardening
kernel.dmesg_restrict = 1              # Restrict dmesg to root
kernel.kptr_restrict = 2               # Hide kernel pointers
kernel.yama.ptrace_scope = 1           # Restrict ptrace

# Network hardening
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
~~~

## Troubleshooting

### Script Fails to Detect Distribution
If auto-detection fails, manually select your distribution when prompted.

### AIDE Initialization Takes Too Long
AIDE initialization can take 10-30 minutes on systems with many files. This is normal.

### Fail2ban Not Starting
Check the journal for errors:
~~~bash
sudo journalctl -u fail2ban -n 50
~~~

### SELinux Denials
If applications fail due to SELinux:
~~~bash
# Check for denials
sudo ausearch -m avc -ts recent

# Generate policy (if legitimate)
sudo audit2allow -a -M mymodule
sudo semodule -i mymodule.pp
~~~

### VSCode Won't Start
If running over SSH, use:
~~~bash
code --disable-gpu
~~~

## Reboot After Installation

After the script completes, **reboot your system** to ensure all kernel parameters and security settings take full effect:

~~~bash
sudo reboot
~~~

## Support

For issues or questions:
- Check `/root/security-setup-*.log` for setup details
- Review system logs: `sudo journalctl -xe`
- Verify services: `sudo systemctl status firewalld fail2ban`

## License

This script is provided as-is for personal and educational use.