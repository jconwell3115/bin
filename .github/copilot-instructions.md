# AI Coding Agent Instructions for bin

## Project Overview
Collection of executable scripts for environment setup, data processing, and automation utilities.

## Architecture
- **Python scripts**: Follow `base_python_script.py` template with argparse and error handling
- **Shell scripts**: Utilities for pip management, git config, and system tasks
- **Templates/**: Code workspace templates (e.g., `template.c-w.j2`)
- **logs/**: Script execution logs (gitignored)

## Key Patterns
- **Script structure**: Copy `base_python_script.py`, customize `sub_main(args)`, parser, and imports
- **Error handling**: Use `exit_with_error(e, traceback)` for detailed exceptions with line numbers
- **Imports**: Try/except blocks listing required modules (e.g., `import pynautobot`)
- **Argparse**: Define arguments in `main()`, parse with `parser.parse_args()`

## Developer Workflows
- **Run script**: `python script.py arg1 arg2` or `./script.sh` for shell scripts
- **Debug**: Add `import pdb; pdb.set_trace()` or print statements in `sub_main()`
- **Test**: Run manually with sample inputs, check logs/ for output
- **Update**: Backup files with `.bak.TIMESTAMP` before modifying

## Conventions
- **File naming**: Descriptive names (e.g., `attach_to_confluence.py`, `csv2markdown.py`)
- **Environment vars**: Use for sensitive data (e.g., `CONFLUENCE_BASIC_AUTH`)
- **Output**: Write to stdout/stderr, use `logs/` for persistent logging
- **Dependencies**: List in try/except; assume virtualenv has required packages

## Integration Points
- **Confluence**: Upload via REST API (see `attach_to_confluence.py`)
- **Git**: Config and secrets management (see `config_git.py`, `git-secrets`)
- **CSV/Excel**: Data processing with `pandas`, `openpyxl` (see `csv2markdown.py`)
- **Network tools**: Inventory and search utilities (see `inventory_from_csv.py`, `search_netmri.py`)

## Examples
- New script: `cp base_python_script.py new_script.py; sed -i 's/{Program Description}/New tool/' new_script.py`
- Confluence upload: `requests.post(url, headers={"Authorization": f"Basic {auth}"}, files=files)`
- CSV processing: `import pandas as pd; df = pd.read_csv(file); df.to_markdown()`</content>
<parameter name="filePath">/home/jconw483/my_work_tools/bin/.github/copilot-instructions.md
