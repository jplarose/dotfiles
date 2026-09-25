import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts/dock-monitors.py"
spec = importlib.util.spec_from_file_location("dock_monitors", SCRIPT)
dock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dock)

# Connector headers and PATH properties captured from this dock with modetest.
DRM_OUTPUT = """Connectors:
id encoder status name size (mm) modes encoders
544 512 connected DP-16 600x340 44 511, 512, 513, 514
  props:
	3 PATH:
		flags: immutable blob
		blobs:

		value:
			6d73743a332d342d3400
	4 TILE:
		flags: immutable blob
		value:
552 513 connected DP-12 600x340 41 511, 512, 513, 514
  props:
	3 PATH:
		flags: immutable blob
		blobs:

		value:
			6d73743a332d322d3200
	473 Colorspace:
		flags: enum
		value: 0
"""
PORTS = [("2-2", "2256x0"), ("4-4", "4816x0")]


def monitor(name, x, model="GS27QA", **extra):
    return dict(name=name, model=model, x=x, y=0, scale=1, **extra)


class DockMonitorTests(unittest.TestCase):
    def test_real_paths_resolve_by_route_not_enumeration_order(self):
        paths = dock.connector_paths(DRM_OUTPUT)
        self.assertEqual(paths, {"DP-12": ("3", "2-2"), "DP-16": ("3", "4-4")})
        monitors = [monitor("DP-16", 2256), monitor("DP-12", 4816)]
        result = dock.resolve(monitors, paths, PORTS, "GS27QA")
        self.assertEqual([m["name"] for _, _, m in result], ["DP-12", "DP-16"])

    def test_renumbering_and_different_laptop_port_preserve_sides(self):
        output = DRM_OUTPUT.replace("DP-12", "DP-27").replace("DP-16", "DP-9")
        output = output.replace("6d73743a33", "6d73743a37")  # mst:3 -> mst:7
        monitors = [monitor("DP-9", 0), monitor("DP-27", 2560)]
        result = dock.resolve(monitors, dock.connector_paths(output), PORTS, "GS27QA")
        self.assertEqual([(pos, m["name"]) for _, pos, m in result],
                         [("2256x0", "DP-27"), ("4816x0", "DP-9")])

    def test_disconnected_and_unknown_displays_are_ignored(self):
        output = DRM_OUTPUT.replace("connected DP-12", "disconnected DP-12")
        paths = dock.connector_paths(output)
        self.assertNotIn("DP-12", paths)
        monitors = [monitor("DP-16", 0, model="Other"), monitor("eDP-1", 0, model="BOE")]
        self.assertEqual(dock.resolve(monitors, paths, PORTS, "GS27QA"), [])

    def test_single_connected_display_gets_its_assigned_position(self):
        monitors = [monitor("DP-16", 0), monitor("DP-12", 0, disabled=True)]
        result = dock.resolve(monitors, dock.connector_paths(DRM_OUTPUT), PORTS, "GS27QA")
        self.assertEqual([(pos, m["name"]) for _, pos, m in result], [("4816x0", "DP-16")])

    def test_ambiguous_route_is_rejected(self):
        monitors = [monitor("DP-12", 0), monitor("DP-99", 0)]
        paths = {"DP-12": ("3", "2-2"), "DP-99": ("7", "2-2")}
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            dock.resolve(monitors, paths, PORTS, "GS27QA")

    def test_pair_from_different_docks_is_rejected(self):
        monitors = [monitor("DP-12", 0), monitor("DP-16", 0)]
        paths = {"DP-12": ("3", "2-2"), "DP-16": ("7", "4-4")}
        with self.assertRaisesRegex(ValueError, "different MST roots"):
            dock.resolve(monitors, paths, PORTS, "GS27QA")

    def test_reconcile_corrects_swapped_outputs_and_then_does_nothing(self):
        args = argparse.Namespace(driver="amdgpu", model="GS27QA", port=PORTS, dry_run=False)
        swapped = json.dumps([monitor("DP-12", 4816), monitor("DP-16", 2256)])
        with patch.object(dock, "run", side_effect=[swapped, DRM_OUTPUT, swapped, "ok\n"]) as run:
            dock.reconcile(args)
            self.assertEqual(run.call_args.args[:2], ("hyprctl", "eval"))
            lua = run.call_args.args[2]
            self.assertIn('output = "DP-12", mode = "preferred", position = "2256x0"', lua)
            self.assertIn('output = "DP-16", mode = "preferred", position = "4816x0"', lua)
        correct = json.dumps([monitor("DP-12", 2256), monitor("DP-16", 4816)])
        with patch.object(dock, "run", side_effect=[correct, DRM_OUTPUT, correct]) as run:
            dock.reconcile(args)
            self.assertEqual(run.call_count, 3)

    def test_no_external_monitors_does_not_query_drm(self):
        args = argparse.Namespace(model="GS27QA")
        with patch.object(dock, "run", return_value='[]') as run:
            dock.reconcile(args)
            self.assertEqual(run.call_count, 1)

    def test_settle_retries_incomplete_dock_enumeration(self):
        args = argparse.Namespace(driver="amdgpu", model="GS27QA", port=PORTS, dry_run=False, settle=True)
        left = json.dumps([monitor("DP-12", 2256)])
        both = json.dumps([monitor("DP-12", 2256), monitor("DP-16", 4816)])
        with patch.object(dock, "run", side_effect=[left, DRM_OUTPUT, left, both, DRM_OUTPUT, both]) as run:
            with patch.object(dock.time, "sleep") as sleep:
                dock.reconcile(args)
        self.assertEqual(run.call_count, 6)
        sleep.assert_called_once_with(0.2)

    def test_settle_retries_transient_ipc_failure(self):
        args = argparse.Namespace(driver="amdgpu", model="GS27QA", port=PORTS, dry_run=False, settle=True)
        both = json.dumps([monitor("DP-12", 2256), monitor("DP-16", 4816)])
        failed = subprocess.CalledProcessError(1, "hyprctl")
        with patch.object(dock, "run", side_effect=[failed, both, DRM_OUTPUT, both]):
            with patch.object(dock.time, "sleep") as sleep:
                dock.reconcile(args)
        sleep.assert_called_once_with(0.2)

    def test_settle_waits_for_positions_before_returning_to_lid_policy(self):
        args = argparse.Namespace(driver="amdgpu", model="GS27QA", port=PORTS, dry_run=False, settle=True)
        swapped = json.dumps([monitor("DP-12", 4816), monitor("DP-16", 2256)])
        correct = json.dumps([monitor("DP-12", 2256), monitor("DP-16", 4816)])
        with patch.object(dock, "run", side_effect=[swapped, DRM_OUTPUT, swapped, "ok", swapped, correct]):
            with patch.object(dock.time, "sleep") as sleep:
                dock.reconcile(args)
        sleep.assert_called_once_with(0.1)

    def test_auto_driver_uses_the_host_gpu_and_rejects_ambiguous_cards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            driver = root / "drivers/i915"
            driver.mkdir(parents=True)
            device = root / "card0/device"
            device.mkdir(parents=True)
            (device / "driver").symlink_to(driver)
            self.assertEqual(dock.detect_driver(root), "i915")
            device = root / "card1/device"
            device.mkdir(parents=True)
            (device / "driver").symlink_to(driver)
            with self.assertRaisesRegex(ValueError, "unique graphics card"):
                dock.detect_driver(root)


if __name__ == "__main__":
    unittest.main()
