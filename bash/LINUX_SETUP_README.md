# RHEL/Rocky Linux Setup Script Usage Guide

## Quick Start

~~~bash
# Download the script directly
wget https://raw.githubusercontent.com/jconwell3115/bin/roadhouse/bash/rhel-rocky-setup.sh

# Make it executable
chmod +x rhel-rocky-setup.sh

# Run as root
sudo ./rhel-rocky-setup.sh
~~~

## Alternative: Clone from Repository

~~~bash
# Clone your bin repository
git clone https://github.com/jconwell3115/bin.git

# Navigate to the bash directory
cd bin/bash

# Make the script executable
chmod +x rhel-rocky-setup.sh

# Execute the script
sudo ./rhel-rocky-setup.sh
~~~

## What Happens When You Run It

The script will:
1. Update all system packages
2. Install EPEL repository
3. Apply comprehensive security hardening
4. Configure firewall and fail2ban
5. Set up Microsoft GPG key
6. Install Visual Studio Code
7. Install development tools
8. Initialize AIDE file integrity monitoring
9. Prompt for reboot

## Post-Installation Commands

### Verify VSCode Installation
~~~bash
code --version
~~~

### Check Firewall Status
~~~bash
sudo firewall-cmd --list-all
~~~

### Monitor Fail2ban
~~~bash
sudo fail2ban-client status sshd
~~~

### Run File Integrity Check
~~~bash
sudo aide --check
~~~

## What This Script Does

### Security Hardening
- ✅ Enables and configures **firewalld**
- ✅ Ensures **SELinux** is in enforcing mode
- ✅ Installs and configures **fail2ban** for SSH protection
- ✅ Sets strong **password policies**
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
- ✅ Installs essential development tools (git, vim, curl, etc.)

## Additional Hardening Recommendations

After running this script, consider these additional steps:

1. **SSH Hardening** - Edit `/etc/ssh/sshd_config`:
   ~~~bash
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   ~~~

2. **Regular AIDE checks**:
   ~~~bash
   aide --check
   ~~~

3. **Monitor fail2ban**:
   ~~~bash
   fail2ban-client status sshd
   ~~~
