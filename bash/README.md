# RHEL/Rocky Linux Setup Script

This script provides automated setup and hardening for RHEL 10 or Rocky Linux systems, including EPEL repository setup, Microsoft GPG key configuration, and VSCode installation.

## Quick Start

~~~bash
# Download the script
wget https://raw.githubusercontent.com/jconwell3115/bin/main/bash/rhel-rocky-setup.sh

# Make it executable
chmod +x rhel-rocky-setup.sh

# Run as root
sudo ./rhel-rocky-setup.sh
~~~

## What This Script Does

### Security Hardening
- ✅ Enables and configures **firewalld**
- ✅ Ensures **SELinux** is in enforcing mode
- ✅ Installs and configures **fail2ban** for SSH protection
- ✅ Sets strong **password policies** (14+ characters, complexity requirements)
- ✅ Enables **automatic security updates**
- ✅ Applies **kernel hardening** parameters
- ✅ Disables **core dumps**
- ✅ Initializes **AIDE** for file integrity monitoring
- ✅ Disables unnecessary services

### Repository Setup
- ✅ Installs **EPEL** repository
- ✅ Enables CRB/PowerTools repository
- ✅ Imports **Microsoft GPG key**
- ✅ Adds **VSCode repository**

### Software Installation
- ✅ Installs **Visual Studio Code**
- ✅ Installs essential development tools (git, vim, curl, wget, htop, tmux, etc.)

## Prerequisites

- RHEL 10 or Rocky Linux system
- Root or sudo access
- Active internet connection

## Usage

### Basic Usage

~~~bash
sudo ./rhel-rocky-setup.sh
~~~

The script will:
1. Update all system packages
2. Install and configure EPEL repository
3. Apply security hardening measures
4. Set up Microsoft GPG key and VSCode repository
5. Install VSCode via RPM
6. Install useful development tools
7. Initialize AIDE file integrity checker
8. Create a security audit log
9. Prompt for system reboot

### Manual Installation

If you prefer to download and run manually:

~~~bash
# Clone the repository
git clone https://github.com/jconwell3115/bin.git
cd bin/bash

# Make executable
chmod +x rhel-rocky-setup.sh

# Run the script
sudo ./rhel-rocky-setup.sh
~~~

## Post-Installation Steps

### 1. SSH Hardening

Edit `/etc/ssh/sshd_config` to disable root login and password authentication:

~~~bash
sudo vim /etc/ssh/sshd_config
~~~

Add or modify these lines:

~~~bash
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
~~~

Then restart SSH:

~~~bash
sudo systemctl restart sshd
~~~

### 2. Review Firewall Rules

~~~bash
# List all firewall rules
sudo firewall-cmd --list-all

# Add additional services as needed
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
~~~

### 3. Monitor Fail2ban

~~~bash
# Check fail2ban status
sudo fail2ban-client status

# Check SSH jail specifically
sudo fail2ban-client status sshd

# Unban an IP if needed
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
~~~

### 4. Run AIDE File Integrity Checks

~~~bash
# Check for file system changes
sudo aide --check

# Update AIDE database after legitimate changes
sudo aide --update
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
~~~

### 5. Verify VSCode Installation

~~~bash
# Check version
code --version

# Launch VSCode
code
~~~

## Security Features Explained

### Kernel Hardening Parameters

The script applies these kernel security parameters:

- **kernel.dmesg_restrict = 1**: Restricts access to kernel logs
- **kernel.kptr_restrict = 2**: Hides kernel pointers
- **kernel.yama.ptrace_scope = 1**: Restricts ptrace usage
- **net.ipv4.tcp_syncookies = 1**: Protects against SYN flood attacks
- **net.ipv4.conf.all.rp_filter = 1**: Enables reverse path filtering

### Password Policies

- Minimum length: 14 characters
- Must contain at least one digit
- Must contain at least one uppercase letter
- Must contain at least one lowercase letter
- Must contain at least one special character

### Automatic Security Updates

The script configures `dnf-automatic` to automatically apply security updates daily.

## Troubleshooting

### VSCode Won't Start

~~~bash
# Check if VSCode is installed
rpm -q code

# Reinstall if needed
sudo dnf reinstall code
~~~

### Firewall Blocking Connections

~~~bash
# Temporarily disable firewall for testing
sudo systemctl stop firewalld

# If that fixes it, add the required service/port
sudo firewall-cmd --permanent --add-port=<PORT>/tcp
sudo firewall-cmd --reload
sudo systemctl start firewalld
~~~

### Fail2ban Banned Your IP

~~~bash
# Check if you're banned
sudo fail2ban-client status sshd

# Unban yourself
sudo fail2ban-client set sshd unbanip <YOUR_IP>
~~~

### SELinux Denials

~~~bash
# Check for SELinux denials
sudo ausearch -m avc -ts recent

# Generate policy if needed
sudo ausearch -m avc -ts recent | audit2allow -M mypolicy
sudo semodule -i mypolicy.pp
~~~

## Customization

You can customize the script by editing these sections:

1. **Firewall rules**: Modify the firewall configuration section to add/remove services
2. **Fail2ban settings**: Adjust `bantime`, `findtime`, and `maxretry` values
3. **Password policies**: Change requirements in `/etc/security/pwquality.conf` section
4. **Development tools**: Add or remove packages from the installation list

## Logs and Audit Trail

The script creates a security audit log at:

~~~bash
/root/security-setup-YYYYMMDD-HHMMSS.log
~~~

This log contains:
- Timestamp of when hardening was completed
- List of security measures applied
- Recommended next steps

## Compatibility

- ✅ RHEL 10
- ✅ Rocky Linux 9/10
- ✅ AlmaLinux 9/10
- ⚠️ May work on other RHEL derivatives with minor modifications

## License

This script is provided as-is for system administrators and DevOps engineers to harden their RHEL-based systems.

## Contributing

Feel free to submit issues or pull requests to improve this script!

## Author

Created by jconwell3115

## Additional Resources

- [RHEL Security Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [VSCode on Linux](https://code.visualstudio.com/docs/setup/linux)
- [Fail2ban Documentation](https://www.fail2ban.org/)
- [AIDE Manual](https://aide.github.io/)