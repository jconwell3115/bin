# Python Scripts

This directory contains standalone Python scripts.

## Guidelines

- Each script should start with `#!/usr/bin/env python3`
- Include a docstring at the top of the file describing what the script does
- Make scripts executable with `chmod +x script_name.py`
- Use descriptive filenames that indicate the script's purpose
- Follow PEP 8 style guidelines
- Include usage examples in the docstring if the script accepts arguments

## Example

```python
#!/usr/bin/env python3
"""
Description: Example script that does something useful
Usage: ./example.py [argument]
"""

def main():
    print("Script executed successfully")

if __name__ == "__main__":
    main()
```
