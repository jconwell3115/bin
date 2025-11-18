# bin

A simple repository for small scripts and utilities that are more one-offs and not project specific.

## Structure

- **bash/** - BASH shell scripts
- **python/** - Python scripts
- **ansible/** - Ansible playbooks (optional)

## Usage

Each directory contains standalone scripts that can be used independently. Scripts should be self-contained and include appropriate documentation within the file.

### BASH Scripts

BASH scripts should include:
- Shebang line (`#!/bin/bash`)
- Brief description of what the script does
- Usage information if the script accepts arguments

### Python Scripts

Python scripts should include:
- Shebang line (`#!/usr/bin/env python3`)
- Docstring describing the script's purpose
- Usage information if the script accepts arguments

### Ansible Playbooks

Ansible playbooks should include:
- Clear task descriptions
- Required variables documented
- Target hosts or groups defined
