"""Verify laptop placement and persistence without changing real displays."""

from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
import re
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "hypr/.local/bin/hypr-monitor-layout"
loader = SourceFileLoader("monitor_layout", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
layout = importlib.util.module_from_spec(spec)
loader.exec_module(layout)


def monitor(name, x=0, y=0, width=2256, height=1504, scale=1, **extra):
    return dict(name=name, x=x, y=y, width=width, height=height, scale=scale,
                refreshRate=60, transform=0, **extra)


class MonitorLayoutTests(unittest.TestCase):
    def setUp(self):
        self.laptop = monitor("eDP-1")
        self.external = monitor("DP-3", x=2256, width=1920, height=1200)

    def target(self, monitors, side):
        return layout.target_position(monitors, "eDP-1", side)

    def test_current_single_external_layout_can_swap_and_swap_back(self):
        monitors = [self.laptop, self.external]
        self.assertEqual(self.target(monitors, "left")[1:], (0, 0))
        self.assertEqual(self.target(monitors, "right")[1:], (1920, 0))
        self.laptop["x"] = 4176
        self.assertEqual(self.target(monitors, "left")[1:], (0, 0))
        self.assertEqual(self.external["x"], 2256)

    def test_multiple_externals_use_outer_edges_despite_enumeration_order(self):
        monitors = [monitor("DP-9", x=4816, width=2560), self.laptop,
                    monitor("DP-4", x=2256, width=2560)]
        self.assertEqual(self.target(monitors, "right")[1:], (7376, 0))
        self.assertEqual(self.target(monitors, "left")[1:], (0, 0))

    def test_scaled_and_rotated_external_geometry(self):
        self.external.update(width=3840, height=2160, scale=2, transform=1, y=200)
        self.assertEqual(self.target([self.laptop, self.external], "right")[1:], (1080, 0))

    def test_laptop_width_accounts_for_its_scale_and_rotation(self):
        self.laptop.update(scale=2, transform=3)
        self.assertEqual(self.target([self.laptop, self.external], "left")[1:], (0, 0))

    def test_single_external_drift_is_recovered(self):
        self.external["x"] = -1920
        self.assertEqual(self.target([self.laptop, self.external], "left")[1:], (0, 0))
        self.assertEqual(self.target([self.laptop, self.external], "right")[1:], (1920, 0))

    def test_undocking_restores_origin_even_with_right_preference(self):
        self.laptop["x"] = 4176
        self.assertEqual(self.target([self.laptop], "right")[1:], (0, 0))

    def test_disabled_fallback_and_mirrored_outputs_are_excluded(self):
        monitors = [self.laptop, monitor("DP-4", disabled=True), monitor("FALLBACK"),
                    monitor("HDMI-A-1", mirrorOf="eDP-1")]
        self.assertEqual(self.target(monitors, "right")[1:], (0, 0))
        self.assertIsNone(self.target([self.external], "right"))

    def test_apply_waits_for_position_and_preserves_mode(self):
        before = json.dumps([self.laptop, self.external])
        after = json.dumps([{**self.laptop, "x": 1920}, {**self.external, "x": 0}])
        with patch.object(layout, "run", side_effect=[before, "ok", before, after]) as run:
            with patch.object(layout.time, "sleep") as sleep:
                layout.apply("right")
        lua = run.call_args_list[1].args[2]
        self.assertIn('position = "1920x0"', lua)
        self.assertIn('output = "DP-3"', lua)
        self.assertIn('position = "0x0"', lua)
        self.assertIn('mode = "2256x1504@60"', lua)
        sleep.assert_called_once_with(0.1)

    def test_correct_position_is_idempotent(self):
        with patch.object(layout, "run", return_value=json.dumps([self.laptop, self.external])) as run:
            layout.apply("left")
        self.assertEqual(run.call_count, 1)

    def test_auto_external_is_pinned_and_repeated_layout_events_converge(self):
        monitors = {m["name"]: m.copy() for m in (self.laptop, self.external)}
        automatic = {"DP-3"}
        evaluations = []

        def compositor(*command):
            if command[1] == "monitors":
                return json.dumps(list(monitors.values()))
            self.assertEqual(command[1], "eval")
            evaluations.append(command[2])
            for name, x, y in re.findall(r'output = "([^"]+)".*?position = "(-?\d+)x(-?\d+)"', command[2]):
                monitors[name].update(x=int(x), y=int(y))
                automatic.discard(name)
            # Hyprland repositions outputs still governed by its `auto` rule.
            for name in automatic:
                monitors[name]["x"] = max(m["x"] + layout.logical_width(m)
                                          for m in monitors.values() if m["name"] != name)
            return "ok"

        with patch.object(layout, "run", side_effect=compositor):
            for _ in range(4):
                layout.apply("right")
        self.assertEqual(len(evaluations), 1)
        self.assertEqual(monitors["DP-3"]["x"], 0)
        self.assertEqual(monitors["eDP-1"]["x"], 1920)

    def test_multiple_external_rules_are_pinned_even_when_already_correct(self):
        second = monitor("DP-4", x=4176, width=1920)
        before = json.dumps([self.laptop, self.external, second])
        after = json.dumps([{**self.laptop, "x": 6096}, self.external, second])
        with patch.object(layout, "run", side_effect=[before, "ok", after]) as run:
            layout.apply("right")
        lua = run.call_args_list[1].args[2]
        self.assertIn('output = "DP-3"', lua)
        self.assertIn('output = "DP-4"', lua)

    def test_rejected_layout_is_reported(self):
        with patch.object(layout, "run", side_effect=[json.dumps([self.laptop, self.external]), "error"]):
            with self.assertRaisesRegex(ValueError, "rejected"):
                layout.apply("right")

    def test_selection_persists_and_reconciles_then_toggle_restores_left(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "hypr/monitor-side"
            with patch.dict(os.environ, {"XDG_STATE_HOME": directory}):
                with patch.object(layout, "run", return_value="") as run:
                    with patch("sys.argv", [str(SCRIPT), "right"]):
                        self.assertEqual(layout.main(), 0)
                    self.assertEqual(path.read_text(), "right\n")
                    run.assert_called_once_with("hypr-lid-manager", "reconcile")
                    with patch("sys.argv", [str(SCRIPT), "toggle"]):
                        self.assertEqual(layout.main(), 0)
                    self.assertEqual(path.read_text(), "left\n")

    def test_dry_run_does_not_save_or_apply(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {"XDG_STATE_HOME": directory}):
                with patch.object(layout, "run", return_value=json.dumps([self.laptop, self.external])) as run:
                    with patch("sys.argv", [str(SCRIPT), "right", "--dry-run"]):
                        self.assertEqual(layout.main(), 0)
                self.assertEqual(run.call_count, 1)
                self.assertFalse((Path(directory) / "hypr").exists())


if __name__ == "__main__":
    unittest.main()
