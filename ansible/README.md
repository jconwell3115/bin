# Ansible Playbooks

This directory contains standalone Ansible playbooks.

## Guidelines

- Use descriptive filenames for playbooks (e.g., `setup_webserver.yml`)
- Include clear task names that describe what each task does
- Document required variables in comments at the top of the playbook
- Specify target hosts or groups clearly
- Use appropriate Ansible best practices

## Example

```yaml
---
# Description: Example playbook that configures something
# Required variables:
#   - target_host: The host to configure
# Usage: ansible-playbook example.yml -i inventory

- name: Example playbook
  hosts: all
  become: yes
  tasks:
    - name: Example task
      debug:
        msg: "Playbook executed successfully"
```
