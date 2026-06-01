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

SCOPE_PRIORITY = ["project", "local", "user"]


def similarity(a, b):
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def plugin_name_from_key(key):
    """Extract the plugin name segment from a registry key.

    Keys look like "plugin-name@repo-name" (e.g. "kk@claude-toolbox").
    """
    return key.split("@")[0]


def best_install_for_entries(entries):
    """Pick the best install path from a list of per-scope entries.

    Prefers project > local > user scope, then most-recently-installed.
    Only returns paths that exist on disk.
    """
    if not isinstance(entries, list):
        entries = [entries]

    def sort_key(entry):
        scope = entry.get("scope", "")
        try:
            scope_rank = SCOPE_PRIORITY.index(scope)
        except ValueError:
            scope_rank = len(SCOPE_PRIORITY)
        return (scope_rank, entry.get("installedAt", ""))

    for entry in sorted(entries, key=sort_key):
        path = entry.get("installPath", "").rstrip("/")
        if path and os.path.isdir(path):
            return path
    return None


def find_plugin_root(plugin_name):
    """
    Find plugin installation directory.

    Returns: (plugin_root_path, match_type)
        match_type: 'exact', 'fuzzy', or None
    """
    plugins_file = Path(os.environ["CPR_PLUGINS_FILE"]) if "CPR_PLUGINS_FILE" in os.environ else Path.home() / ".claude" / "plugins" / "installed_plugins.json"

    if not plugins_file.exists():
        return None, None

    try:
        with open(plugins_file, "r") as f:
            data = json.load(f)
            plugins = data.get("plugins", {})
    except (OSError, json.JSONDecodeError):
        return None, None

    # Exact match: plugin name segment matches (case-insensitive)
    for key, entries in plugins.items():
        if plugin_name_from_key(key).lower() == plugin_name.lower():
            path = best_install_for_entries(entries)
            if path:
                return path, "exact"

    # Fuzzy match on the plugin name segment
    matches = []
    for key, entries in plugins.items():
        name_part = plugin_name_from_key(key)
        ratio = similarity(plugin_name, name_part)
        if ratio > 0.6:
            path = best_install_for_entries(entries)
            if path:
                matches.append((ratio, path, key))

    if matches:
        matches.sort(reverse=True, key=lambda x: x[0])
        return matches[0][1], "fuzzy"

    return None, None


def main():
    if len(sys.argv) < 2:
        print(f"Usage: python3 {sys.argv[0]} <plugin-name>", file=sys.stderr)
        print(f"Example: python3 {sys.argv[0]} kk", file=sys.stderr)
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
            "Checked: ~/.claude/plugins/installed_plugins.json",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
