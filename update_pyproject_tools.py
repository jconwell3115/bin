#!/usr/bin/env python3
"""
Update pyproject.toml tool configurations from global_env template.

This script merges tool configurations from global_env/pyproject.toml into
a project's pyproject.toml, preserving project-specific settings like
dependencies, UV configuration, and dependency groups, including comments.
"""

import sys
from pathlib import Path
from typing import Any, Dict
import tomlkit


def load_toml(file_path: str | Path) -> Dict[str, Any]:
    """Load a TOML file with comments preserved."""
    with open(file_path, "r") as f:
        return tomlkit.load(f)


def save_toml(data: Dict[str, Any], file_path: str | Path) -> None:
    """Save TOML data with comments preserved."""
    with open(file_path, "w") as f:
        tomlkit.dump(data, f)


def update_pyproject_tools(
    global_pyproject_path: str | Path, project_pyproject_path: str | Path
) -> None:
    """
    Update tool configurations in project pyproject.toml from global template.

    Preserves:
    - [project] section and its comments
    - [tool.uv] section and its comments
    - [dependency-groups] section and its comments
    - All comments throughout the file

    Updates all [tool.*] sections except [tool.uv]
    """
    # Load both files (preserving comments in project file)
    global_config = load_toml(global_pyproject_path)
    project_config = load_toml(project_pyproject_path)

    # Update tool sections from global (except uv which is preserved)
    if "tool" in global_config:
        if "tool" not in project_config:
            project_config["tool"] = tomlkit.table()

        for key, value in global_config["tool"].items():
            if key != "uv":  # Preserve project's uv config
                project_config["tool"][key] = value

    # Save updated config (preserves all comments and formatting)
    save_toml(project_config, project_pyproject_path)
    print(
        f"Updated {project_pyproject_path} with tool configurations from {global_pyproject_path}"
    )


def main() -> None:
    if len(sys.argv) != 3:
        print(
            "Usage: python update_pyproject_tools.py <global_pyproject.toml> <project_pyproject.toml>"
        )
        print(
            "Example: python update_pyproject_tools.py global_env/pyproject.toml my_project/pyproject.toml"
        )
        sys.exit(1)

    global_path = Path(sys.argv[1])
    project_path = Path(sys.argv[2])

    if not global_path.exists():
        print(f"Error: Global pyproject.toml not found: {global_path}")
        sys.exit(1)

    if not project_path.exists():
        print(f"Error: Project pyproject.toml not found: {project_path}")
        sys.exit(1)

    try:
        update_pyproject_tools(global_path, project_path)
        print("Update completed successfully!")
    except Exception as e:
        print(f"Error updating pyproject.toml: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
