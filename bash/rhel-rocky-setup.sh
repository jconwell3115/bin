#!/bin/bash

# RHEL 10 / Rocky Linux Setup Script
# This script hardens the system, sets up EPEL, and installs VSCode

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root"
   exit 1
fi

echo_info "Starting RHEL/Rocky Linux setup and hardening..."

# ============================================
# 1. SYSTEM UPDATES
# ============================================
echo_info "Updating system packages..."
dnf update -y
dnf upgrade -y

# ============================================
# 2. INSTALL EPEL REPOSITORY
# ============================================
echo_info "Installing EPEL repository..."
dnf install -y epel-release
dnf config-manager --set-enabled crb 2>/dev/null || dnf config-manager --set-enabled powertools 2>/dev/null || true

# ============================================
# 3. BASIC SYSTEM HARDENING
# ============================================
echo_info "Applying basic system hardening..."

# Install security tools
dnf install -y fail2ban aide firewalld

# Configure and enable firewall
echo_info "Configuring firewall..."
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --set-default-zone=public
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Enable and configure SELinux
echo_info "Ensuring SELinux is enabled..."
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
fi

# Configure fail2ban
echo_info "Configuring fail2ban..."
systemctl enable fail2ban
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
EOF
systemctl start fail2ban

# Disable unnecessary services
echo_info "Disabling unnecessary services..."
systemctl disable postfix 2>/dev/null || true

# Set stronger password policies
echo_info "Configuring password policies..."
dnf install -y libpwquality
cat > /etc/security/pwquality.conf <<EOF
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

# Configure automatic security updates
echo_info "Configuring automatic security updates..."
dnf install -y dnf-automatic
sed -i 's/^apply_updates = .*/apply_updates = yes/' /etc/dnf/automatic.conf
sed -i 's/^upgrade_type = .*/upgrade_type = security/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer

# Set secure umask
echo_info "Setting secure umask..."
echo "umask 027" >> /etc/profile

# Disable core dumps
echo_info "Disabling core dumps..."
cat >> /etc/security/limits.conf <<EOF
* hard core 0
EOF
echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf

# Kernel hardening parameters
echo_info "Applying kernel hardening parameters..."
cat >> /etc/sysctl.conf <<EOF
# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# Network hardening
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF
sysctl -p

# ============================================
# 4. SETUP MICROSOFT GPG KEY AND VSCODE REPO
# ============================================
echo_info "Setting up Microsoft GPG key..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo_info "Adding VSCode repository..."
cat > /etc/yum.repos.d/vscode.repo <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# ============================================
# 5. INSTALL VSCODE
# ============================================
echo_info "Installing Visual Studio Code..."
dnf check-update
dnf install -y code

# Verify installation
if command -v code &> /dev/null; then
    echo_info "VSCode installed successfully: $(code --version | head -n1)"
else
    echo_error "VSCode installation failed"
    exit 1
fi

# ============================================
# 6. INSTALL USEFUL DEVELOPMENT TOOLS
# ============================================
echo_info "Installing useful development tools..."
dnf install -y \
    git \
    wget \
    curl \
    vim \
    htop \
    tmux \
    unzip \
    tar \
    bzip2

# ============================================
# 7. INITIALIZE AIDE (File Integrity Checker)
# ============================================
echo_info "Initializing AIDE database (this may take a few minutes)..."
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# ============================================
# FINAL STEPS
# ============================================
echo_info "Creating security audit log..."
cat > /root/security-setup-$(date +%Y%m%d-%H%M%S).log <<EOF
System Hardening Completed: $(date)
===========================================
- System updated
- EPEL repository installed
- Firewall enabled and configured
- SELinux set to enforcing
- Fail2ban installed and configured
- Password policies strengthened
- Automatic security updates enabled
- Kernel hardening applied
- AIDE initialized
- VSCode installed with Microsoft GPG key

Next Recommended Steps:
1. Review firewall rules: firewall-cmd --list-all
2. Configure SSH key-based authentication
3. Disable password authentication in /etc/ssh/sshd_config
4. Review and customize fail2ban jails
5. Run AIDE checks regularly: aide --check
6. Set up regular backups
7. Configure log monitoring
EOF

echo_info "============================================"
echo_info "Setup completed successfully!"
echo_info "============================================"
echo_info "Installed packages:"
echo_info "  - EPEL repository"
echo_info "  - Visual Studio Code ($(rpm -q code))"
echo_info "  - Security tools (firewalld, fail2ban, aide)"
echo_info ""
echo_warn "IMPORTANT: Review the security settings and customize as needed"
echo_warn "A reboot is recommended to apply all kernel parameters"
echo_info "Setup log saved to: /root/security-setup-$(date +%Y%m%d-%H%M%S).log"
echo_info ""
echo_info "To start VSCode, run: code"

# Ask for reboot
read -p "Do you want to reboot now? (y/N):" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo_info "Rebooting system..."
    reboot
fi