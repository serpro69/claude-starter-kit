# Common helper

A shared instruction reused across skills. It is reached through the per-skill
symlink, so its node carries the fan-in from every consuming skill while its own
outgoing links are attributed to this one canonical path.
