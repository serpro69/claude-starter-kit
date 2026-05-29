#!/usr/bin/env python3
"""
Claude Plugin Root (CPR) Resolver

Usage:   cpr.py <plugin-name>
Returns: absolute path to plugin installation directory

Searches for plugins in ~/.claude/plugins/installed_plugins.json with fuzzy matching.

KNOWN ISSUES:
    - problem:
        - `claude plugin list` shows the plugin as installed
        - ~/.claude/plugins/installed_plugins.json does not have a project entry for the plugin
      solution:
        - re-run `claude plugin install kk@claude-toolbox --scope project`
          (or the scope where you have the plugin installed as shown by the `claude plugin list` command)
"""

import json
import os
import sys
from pathlib import Path
from difflib import SequenceMatcher


def similarity(a, b):
    """Calculate similarity ratio between two strings."""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def find_plugin_root(plugin_name):
    """
    Find plugin installation directory.

    Returns: (plugin_root_path, match_type)
        match_type: 'env_var', 'exact', 'fuzzy', or None
    """
    # Try CLAUDE_PLUGIN_ROOT first (backwards compatible)
    env_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env_root and os.path.isdir(env_root):
        return env_root.rstrip("/"), "env_var"

    # Read installed_plugins.json
    plugins_file = Path.home() / ".claude" / "plugins" / "installed_plugins.json"

    if not plugins_file.exists():
        return None, None

    try:
        with open(plugins_file, "r") as f:
            data = json.load(f)
            plugins = data.get("plugins", {})
    except (OSError, json.JSONDecodeError):
        return None, None

    # Try exact match first (case-insensitive)
    for key, value in plugins.items():
        if plugin_name.lower() in key.lower():
            # Handle list or dict value
            if isinstance(value, list) and len(value) > 0:
                value = value[0]
            install_path = value.get("installPath", "").rstrip("/")
            if install_path and os.path.isdir(install_path):
                return install_path, "exact"

    # Try fuzzy matching if no exact match
    matches = []
    for key, value in plugins.items():
        # Extract just the plugin name from key (e.g., "owner/plugin-name" -> "plugin-name")
        key_parts = key.split("/")
        plugin_part = key_parts[-1] if key_parts else key
        # Also handle @ separator (e.g., "plugin-name@plugin-name")
        plugin_part = plugin_part.split("@")[0]

        ratio = similarity(plugin_name, plugin_part)
        if ratio > 0.6:  # 60% similarity threshold
            # Handle list or dict value
            if isinstance(value, list) and len(value) > 0:
                value = value[0]
            install_path = value.get("installPath", "").rstrip("/")
            if install_path and os.path.isdir(install_path):
                matches.append((ratio, install_path, key))

    if matches:
        # Return best match
        matches.sort(reverse=True, key=lambda x: x[0])
        best_match = matches[0]
        return best_match[1], "fuzzy"

    return None, None


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 /tmp/cpr.py <plugin-name>", file=sys.stderr)
        print("Example: python3 /tmp/cpr.py readme-and-co", file=sys.stderr)
        sys.exit(1)

    plugin_name = sys.argv[1]
    plugin_root, _ = find_plugin_root(plugin_name)

    if plugin_root:
        # Output just the path to stdout (for command substitution)
        print(plugin_root)
        sys.exit(0)
    else:
        print(f"Error: Could not locate plugin '{plugin_name}'", file=sys.stderr)
        print(
            "Checked: $CLAUDE_PLUGIN_ROOT, ~/.claude/plugins/installed_plugins.json",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
