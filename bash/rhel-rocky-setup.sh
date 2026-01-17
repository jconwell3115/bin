#!/bin/bash

# RHEL / Fedora Linux Setup Script
# This script hardens the system, sets up repositories, and installs VSCode

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo_prompt() {
    echo -e "${BLUE}[INPUT]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root"
   exit 1
fi

# ============================================
# DISTRO DETECTION
# ============================================
echo_info "Detecting Linux distribution..."

DISTRO=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "fedora" ]]; then
        DISTRO="fedora"
        echo_info "Detected: Fedora $VERSION_ID"
    elif [[ "$ID" == "rhel" ]]; then
        DISTRO="rhel"
        echo_info "Detected: Red Hat Enterprise Linux $VERSION_ID"
    else
        echo_warn "Detected: $PRETTY_NAME (may not be fully supported)"
    fi
fi

# Prompt user to confirm or manually select
echo ""
echo_prompt "Select your distribution:"
echo "1) Fedora"
echo "2) RHEL (Red Hat Enterprise Linux)"
echo ""
read -p "Enter choice [1-2] (detected: $DISTRO): " choice

case $choice in
    1)
        DISTRO="fedora"
        echo_info "Selected: Fedora"
        ;; 
    2)
        DISTRO="rhel"
        echo_info "Selected: RHEL"
        ;;  
    "")
        if [ -z "$DISTRO" ]; then
            echo_error "Could not detect distribution. Please run again and select manually."
            exit 1
        fi
        echo_info "Using detected distribution: $DISTRO"
        ;;  
    *)
        echo_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo_info "Starting $DISTRO setup and hardening..."
echo ""

# ============================================
# 1. SYSTEM UPDATES
# ============================================
echo_info "Updating system packages..."
dnf update -y
dnf upgrade -y

# ============================================
# 2. INSTALL DISTRIBUTION-SPECIFIC REPOS
# ============================================
if [ "$DISTRO" == "rhel" ]; then
    echo_info "Installing EPEL repository for RHEL..."
dnf install -y epel-release
    
echo_info "Enabling CRB (CodeReady Builder) repository..."
dnf config-manager --set-enabled crb 2>/dev/null || \
dnf config-manager --set-enabled powertools 2>/dev/null || \
echo_warn "Could not enable CRB/PowerTools (may not be available on this RHEL version)"
    
elif [ "$DISTRO" == "fedora" ]; then
    echo_info "Fedora detected - repositories already available"
    
echo_info "Enabling RPM Fusion repositories (optional but recommended)..."
dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    2>/dev/null || echo_warn "RPM Fusion installation failed or already installed"
fi

# ============================================
# 3. INSTALL FLATPAK AND FLATHUB REPOSITORY
# ============================================
echo_info "Installing Flatpak..."
dnf install -y flatpak

echo_info "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo_info "Flatpak and Flathub repository installed successfully"

# ============================================
# 4. BASIC SYSTEM HARDENING
# ============================================
echo_info "Applying basic system hardening..."

# Install security tools
echo_info "Installing security tools..."
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
grep -q "umask 027" /etc/profile || echo "umask 027" >> /etc/profile

# Disable core dumps
echo_info "Disabling core dumps..."
grep -q "* hard core 0" /etc/security/limits.conf || cat >> /etc/security/limits.conf <<EOF
* hard core 0
EOF
grep -q "fs.suid_dumpable" /etc/sysctl.conf || echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf

# Kernel hardening parameters
echo_info "Applying kernel hardening parameters..."
cat >> /etc/sysctl.d/99-security-hardening.conf <<EOF
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
sysctl -p /etc/sysctl.d/99-security-hardening.conf

# ============================================
# 5. SETUP MICROSOFT GPG KEY AND VSCODE REPO
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
# 6. INSTALL VSCODE
# ============================================
echo_info "Installing Visual Studio Code..."
dnf check-update || true
dnf install -y code

# Verify installation
if command -v code &> /dev/null; then
    echo_info "VSCode installed successfully: $(code --version | head -n1)"
else
    echo_error "VSCode installation failed"
    exit 1
fi

# ============================================
# 7. INSTALL USEFUL DEVELOPMENT TOOLS
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
    bzip2 \
    neofetch

# ============================================
# 8. INITIALIZE AIDE (File Integrity Checker)
# ============================================
echo_info "Initializing AIDE database (this may take a few minutes)..."
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# ============================================
# FINAL STEPS
# ============================================
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/root/security-setup-$TIMESTAMP.log"

echo_info "Creating security audit log..."
cat > "$LOG_FILE" <<EOF
System Hardening Completed: $(date)
Distribution: $DISTRO
===========================================
- System updated
$([ "$DISTRO" == "rhel" ] && echo "- EPEL repository installed" || echo "- RPM Fusion repositories installed")
- Flatpak and Flathub repository installed
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
8. Install Flatpak apps: flatpak install flathub <app-id>
EOF

echo ""
echo_info "============================================="
echo_info "Setup completed successfully!"
echo_info "============================================="
echo_info "Distribution: $DISTRO"
echo_info "Installed packages:"
if [ "$DISTRO" == "rhel" ]; then
    echo_info "  - EPEL repository"
else
    echo_info "  - RPM Fusion repositories"
fi
echo_info "  - Flatpak with Flathub repository"
echo_info "  - Visual Studio Code ($(rpm -q code))"
echo_info "  - Security tools (firewalld, fail2ban, aide)"
echo_info ""
echo_warn "IMPORTANT: Review the security settings and customize as needed"
echo_warn "A reboot is recommended to apply all kernel parameters"
echo_info "Setup log saved to: $LOG_FILE"
echo_info ""
echo_info "Useful commands:"
echo_info "  - Start VSCode: code"
echo_info "  - Search Flatpak apps: flatpak search <app-name>"
echo_info "  - Install Flatpak apps: flatpak install flathub <app-id>"
echo_info "  - Check system info: neofetch"
echo ""

# Ask for reboot
read -p "Do you want to reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo_info "Rebooting system..."
    reboot
fi
