#!/usr/bin/env python3
"""Print effective RAM capacity in MiB, respecting visible cgroup limits."""

import re
from pathlib import Path


def read_text(path):
    try:
        return path.read_text()
    except OSError:
        return ""


def unescape_mount(value):
    return re.sub(r"\\([0-7]{3})", lambda match: chr(int(match[1], 8)), value)


def memory_capacity(proc=Path("/proc")):
    limits = []
    for line in read_text(proc / "meminfo").splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0] == "MemTotal:" and fields[1].isdigit():
            limits.append(int(fields[1]) * 1024)

    groups = {}
    for line in read_text(proc / "self/cgroup").splitlines():
        fields = line.split(":", 2)
        if len(fields) == 3:
            if fields[0] == "0" and not fields[1]:
                groups["cgroup2"] = fields[2]
            elif "memory" in fields[1].split(","):
                groups["cgroup"] = fields[2]

    for line in read_text(proc / "self/mountinfo").splitlines():
        before, separator, after = line.partition(" - ")
        fields, filesystem = before.split(), after.split()
        if not separator or len(fields) < 5 or len(filesystem) < 3:
            continue
        kind = filesystem[0]
        if kind not in groups:
            continue
        if kind == "cgroup" and "memory" not in filesystem[2].split(","):
            continue
        root = Path(unescape_mount(fields[3]))
        mount = Path(unescape_mount(fields[4]))
        group = Path(groups[kind])
        try:
            relative = group.relative_to(root)
        except ValueError:
            # A private cgroup namespace reports its own root as /.
            if group != Path("/"):
                continue
            relative = Path(".")
        if ".." in relative.parts:
            continue
        directory = mount / relative
        filename = "memory.max" if kind == "cgroup2" else "memory.limit_in_bytes"
        # An ancestor can impose a stricter limit than the container itself.
        while True:
            value = read_text(directory / filename).strip()
            if value.isdigit():
                limits.append(int(value))
            if directory == mount:
                break
            directory = directory.parent

    return min(limits) // (1024 * 1024) if limits else None


if __name__ == "__main__":
    capacity = memory_capacity()
    if capacity is not None:
        print(capacity)
