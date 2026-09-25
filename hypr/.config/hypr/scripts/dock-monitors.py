#!/usr/bin/env python3
"""Resolve dock MST port routes to current Hyprland output names.

Requires Python 3 and modetest (libdrm). See conf/monitors/README.md.
"""

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def run(*command):
    return subprocess.run(
        command, check=True, capture_output=True, text=True, timeout=10,
        env={**os.environ, "LC_ALL": "C"},
    ).stdout


def detect_driver(drm_root=Path("/sys/class/drm")):
    cards = [card for card in drm_root.glob("card*")
             if re.fullmatch(r"card\d+", card.name) and (card / "device/driver").exists()]
    if len(cards) != 1:
        raise ValueError("Cannot choose a unique graphics card; specify --driver explicitly")
    return (cards[0] / "device/driver").resolve().name


def connector_paths(output):
    """Read connected outputs' immutable PATH blobs from modetest -c."""
    headers = list(re.finditer(
        r"(?m)^\d+\s+\d+\s+(connected|disconnected|unknown)\s+(\S+)\s", output,
    ))
    paths = {}
    for index, header in enumerate(headers):
        if header[1] != "connected":
            continue
        end = headers[index + 1].start() if index + 1 < len(headers) else len(output)
        block = output[header.end():end]
        prop = re.search(r"(?ms)^\t\d+ PATH:\n(.*?)(?=^\t\d+ [^\n]+:\n|\Z)", block)
        if not prop:
            continue
        encoded = "".join(re.findall(r"(?m)^\t{3}([0-9a-fA-F]+)$", prop[1]))
        path = bytes.fromhex(encoded).rstrip(b"\0").decode("ascii")
        match = re.fullmatch(r"mst:(\d+)-(\d+(?:-\d+)*)", path)
        if match:
            # The prefix identifies the upstream connector, which may change
            # when moving the dock to another laptop port. Keep it only to
            # reject ambiguous matches across multiple MST roots.
            paths[header[2]] = (match[1], match[2])
    return paths


def resolve(monitors, paths, ports, model):
    resolved = []
    roots = set()
    for route, position in ports:
        matches = [
            monitor for monitor in monitors
            if not monitor.get("disabled", False)
            and monitor.get("model") == model
            and paths.get(monitor["name"], (None, None))[1] == route
        ]
        if len(matches) > 1:
            raise ValueError(f"Dock route {route} is ambiguous; leaving the layout alone")
        if matches:
            monitor = matches[0]
            roots.add(paths[monitor["name"]][0])
            resolved.append((route, position, monitor))
    if len(roots) > 1:
        raise ValueError("Dock routes belong to different MST roots; leaving the layout alone")
    return resolved


def port_argument(value):
    match = re.fullmatch(r"(\d+(?:-\d+)*)=(-?\d+x-?\d+)", value)
    if not match:
        raise argparse.ArgumentTypeError("Expected ROUTE=XxY, for example 2-2=2256x0")
    return match[1], match[2]


def reconcile(args):
    attempts = 10 if getattr(args, "settle", False) else 1
    for attempt in range(attempts):
        try:
            monitors = json.loads(run("hyprctl", "monitors", "all", "-j"))
            if not any(m.get("model") == args.model for m in monitors):
                return
            driver = detect_driver() if args.driver == "auto" else args.driver
            paths = connector_paths(run("modetest", "-M", driver, "-c"))
            # Query again after DRM enumeration, as hotplug can change the live set.
            monitors = json.loads(run("hyprctl", "monitors", "all", "-j"))
            resolved = resolve(monitors, paths, args.port, args.model)
            if len(resolved) == len(args.port) or attempt == attempts - 1:
                break
        except (OSError, ValueError, subprocess.SubprocessError):
            if attempt == attempts - 1:
                raise
        # A dock can announce its displays before their PATH/modes are ready.
        time.sleep(0.2)
    changes = []
    for route, position, monitor in resolved:
        x, y = map(int, position.split("x"))
        correct = (monitor["x"], monitor["y"], monitor["scale"]) == (x, y, 1)
        if args.dry_run:
            state = "already correct" if correct else "would move"
            print(f"route {route}: {monitor['name']} -> {position}, scale 1 ({state})")
        elif not correct:
            # json.dumps safely quotes the ASCII output name and position for Lua.
            changes.append(
                "hl.monitor({ output = " + json.dumps(monitor["name"])
                + ', mode = "preferred", position = ' + json.dumps(position)
                + ", scale = 1 })"
            )
    if args.dry_run and not resolved:
        print("No matching dock routes are connected; leaving the layout alone")
    if changes:
        response = run("hyprctl", "eval", "\n".join(changes)).strip()
        if response != "ok":
            raise ValueError(f"Hyprland rejected the monitor layout: {response}")
        if getattr(args, "settle", False):
            # Workspace ownership must be calculated using the applied positions.
            for _ in range(10):
                current = {m["name"]: m for m in json.loads(run("hyprctl", "monitors", "all", "-j"))}
                if all(
                    m["name"] in current
                    and (current[m["name"]]["x"], current[m["name"]]["y"], current[m["name"]]["scale"])
                    == (*map(int, position.split("x")), 1)
                    for _, position, m in resolved
                ):
                    break
                time.sleep(0.1)
            else:
                raise ValueError("Monitor layout did not settle; a later hotplug event will retry")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--driver", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--port", action="append", type=port_argument, required=True)
    parser.add_argument("--dry-run", action="store_true", help="Print the resolved layout without changing it")
    parser.add_argument("--settle", action="store_true", help="Retry dock enumeration and wait for applied positions")
    args = parser.parse_args()
    if len({route for route, _ in args.port}) != len(args.port):
        parser.error("Each dock route may only appear once")
    try:
        if args.dry_run:
            reconcile(args)
        else:
            # Serialize event bursts. Waiting, rather than dropping a request,
            # ensures a hotplug during an earlier invocation is reconciled too.
            signature = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
            lock = Path(os.environ["XDG_RUNTIME_DIR"]) / f"hypr-dock-monitors-{signature}.lock"
            with lock.open("w") as handle:
                fcntl.flock(handle, fcntl.LOCK_EX)
                reconcile(args)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"dock-monitors: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
