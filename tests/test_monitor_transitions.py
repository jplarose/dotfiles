"""Exercise the real Bash policy with mocked hardware/IPC; never change displays."""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
LID = ROOT / "hypr/.local/bin/hypr-lid-manager"
WORKSPACES = ROOT / "hypr/.local/bin/hypr-workspace-manager"


def monitor(name, workspace=1, x=0, focused=False, disabled=False):
    return dict(name=name, activeWorkspace={"id": workspace}, x=x, y=0, scale=1,
                focused=focused, disabled=disabled, dpmsStatus=True)


LID_MOCKS = r'''
physical_lid_state() { cat "$TEST_LID"; }
sleep() { :; }
hyprctl() {
    printf '%s\n' "$*" >> "$TEST_CALLS"
    case "$1" in
        monitors) cat "$TEST_MONITORS" ;;
        *) printf 'ok\n' ;;
    esac
}
loginctl() { printf 'loginctl %s\n' "$*" >> "$TEST_CALLS"; }
systemctl() { printf 'systemctl %s\n' "$*" >> "$TEST_CALLS"; }
start_inhibitor() { printf 'inhibit %s\n' "$2" >> "$TEST_CALLS"; }
stop_inhibitor() { printf 'uninhibit %s\n' "$1" >> "$TEST_CALLS"; }
reconcile_workspaces() {
    local parked=no
    panel_parked && parked=yes
    printf 'workspaces parked=%s group=%s\n' "$parked" "${1:-auto}" >> "$TEST_CALLS"
}
'''


class MonitorTransitionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.runtime = Path(self.temp.name)
        self.calls = self.runtime / "calls"
        self.calls.touch()
        self.monitors = self.runtime / "monitors.json"
        self.lid = self.runtime / "lid"
        self.lid.write_text("closed\n")
        self.parked = self.runtime / "hypr-lid-parked-panel"
        self.env = {**os.environ, "XDG_RUNTIME_DIR": str(self.runtime),
                    "TEST_CALLS": str(self.calls), "TEST_MONITORS": str(self.monitors),
                    "TEST_LID": str(self.lid)}
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        self.env.pop("HYPR_WORKSPACE_MODE", None)
        self.set_monitors([monitor("eDP-1"), monitor("DP-12", 3, 2256, True),
                           monitor("DP-16", 4, 4816)])

    def set_monitors(self, monitors):
        self.monitors.write_text(json.dumps(monitors))

    def shell(self, body, script=LID, mocks=LID_MOCKS, check=True):
        result = subprocess.run(["bash", "-c", 'source "$1"\n' + mocks + body,
                                 "test-monitor", str(script)], env=self.env,
                                capture_output=True, text=True, timeout=5)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def log(self):
        return self.calls.read_text()

    def test_close_event_parks_laptop_and_keeps_dock_awake(self):
        self.shell("main close")
        self.assertEqual(self.parked.read_text().strip(), "eDP-1")
        self.assertIn('action = "off", monitor = "eDP-1"', self.log())
        self.assertIn('action = "on", monitor = "DP-12"', self.log())
        self.assertIn("workspaces parked=yes", self.log())
        self.assertIn("inhibit sleep", self.log())
        self.assertNotIn("loginctl", self.log())

    def test_open_event_restores_panel_before_workspace_reconciliation(self):
        self.parked.write_text("eDP-1\n")
        self.lid.write_text("open\n")
        self.shell("main open")
        self.assertFalse(self.parked.exists())
        self.assertIn('action = "on", monitor = "eDP-1"', self.log())
        self.assertIn("workspaces parked=no group=2", self.log())
        self.assertNotIn("inhibit sleep", self.log())

    def test_false_close_event_does_not_blank_open_laptop(self):
        self.lid.write_text("open\n")
        self.shell("main close")
        self.assertFalse(self.parked.exists())
        self.assertNotIn("dispatch", self.log())

    def test_closed_undock_unparks_and_locks_without_immediate_suspend(self):
        self.parked.write_text("eDP-1\n")
        self.set_monitors([monitor("eDP-1", 3, focused=True)])
        self.shell("main reconcile")
        self.assertFalse(self.parked.exists())
        self.assertIn("workspaces parked=no", self.log())
        self.assertIn("loginctl lock-session", self.log())
        self.assertIn('action = "off", monitor = "eDP-1"', self.log())
        self.assertNotIn("systemctl suspend", self.log())

    def test_open_undock_restores_visible_laptop(self):
        self.parked.write_text("eDP-1\n")
        self.lid.write_text("open\n")
        self.set_monitors([monitor("eDP-1", 3, focused=True)])
        self.shell("main reconcile")
        self.assertFalse(self.parked.exists())
        self.assertIn('action = "on", monitor = "eDP-1"', self.log())
        self.assertIn("workspaces parked=no group=3", self.log())

    def test_fallback_output_is_not_a_dock(self):
        self.set_monitors([monitor("eDP-1"), monitor("FALLBACK")])
        self.shell("main reconcile")
        self.assertFalse(self.parked.exists())
        self.assertIn("loginctl lock-session", self.log())
        self.assertNotIn("inhibit sleep", self.log())

    def test_resume_does_not_light_closed_laptop_panel(self):
        self.shell("main resume")
        self.assertIn('action = "on", monitor = "DP-12"', self.log())
        self.assertNotIn('action = "on", monitor = "eDP-1"', self.log())
        self.assertNotIn('hl.dsp.dpms({ action = "on" })', self.log())

    def test_desktop_without_panel_still_reconciles_workspaces(self):
        self.set_monitors([monitor("DP-12", 1, focused=True)])
        self.shell("main reconcile")
        self.assertIn("workspaces parked=no", self.log())
        self.assertNotIn('monitor = "eDP-1"', self.log())

    def test_ipc_failure_does_not_unpark_or_change_power_policy(self):
        self.parked.write_text("eDP-1\n")
        result = self.shell("hyprctl() { return 1; }\nmain reconcile", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.parked.exists())
        self.assertNotIn("uninhibit", self.log())

    def test_busy_lock_queues_the_open_event(self):
        self.lid.write_text("open\n")
        self.parked.write_text("eDP-1\n")
        with (self.runtime / "hypr-lid-manager.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen(["bash", "-c", 'source "$1"\n' + LID_MOCKS + "main open",
                                        "test-monitor", str(LID)], env=self.env,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                time.sleep(0.1)
                self.assertIsNone(process.poll(), "The event was discarded while the lock was busy")
                fcntl.flock(lock, fcntl.LOCK_UN)
                _, stderr = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, stderr)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()
        self.assertFalse(self.parked.exists())

    def test_watcher_retries_failed_transition_without_another_hotplug(self):
        entry = self.runtime / "retry-entry"
        entry.write_text('#!/bin/bash\nif [[ ! -f "$XDG_RUNTIME_DIR/attempted" ]]; then\n'
                         ' touch "$XDG_RUNTIME_DIR/attempted"\n exit 1\nfi\n'
                         'touch "$XDG_RUNTIME_DIR/retried"\n')
        entry.chmod(0o755)
        body = 'source "$1"\n' + LID_MOCKS + '''
polls=0
sleep() { ((++polls)); if (( polls >= 2 )); then exit 0; fi; }
watch_hotplug
'''
        result = subprocess.run(["bash", "-c", body, str(entry), str(LID)], env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.runtime / "retried").exists())

    def test_watcher_signature_detects_lid_but_ignores_idle_blanking(self):
        closed = self.shell("topology_signature").stdout
        monitors = json.loads(self.monitors.read_text())
        for m in monitors:
            m["dpmsStatus"] = False
        self.set_monitors(monitors)
        self.assertEqual(self.shell("topology_signature").stdout, closed)
        self.lid.write_text("open\n")
        self.assertNotEqual(self.shell("topology_signature").stdout, closed)

    def test_watcher_detects_resolution_changes(self):
        before = self.shell("topology_signature").stdout
        monitors = json.loads(self.monitors.read_text())
        monitors[1].update(width=3840, height=2160)
        self.set_monitors(monitors)
        self.assertNotEqual(self.shell("topology_signature").stdout, before)

    def test_laptop_layout_settles_before_workspace_ownership_changes(self):
        # Exercise the real orchestration function with only the commands mocked.
        mocks = r'''
hypr-monitor-layout() { printf 'layout %s\n' "$*" >> "$TEST_CALLS"; }
hypr-workspace-manager() { printf 'workspaces %s\n' "$*" >> "$TEST_CALLS"; }
'''
        self.shell("reconcile_workspaces 2", mocks=mocks)
        self.assertEqual(self.log(), "layout apply\nworkspaces reconcile 2\n")

    def test_workspace_fallback_includes_last_panel_despite_stale_marker(self):
        self.parked.write_text("eDP-1\n")
        self.set_monitors([monitor("eDP-1", focused=True), monitor("FALLBACK")])
        result = self.shell("visible_monitors_json", script=WORKSPACES)
        self.assertEqual([m["name"] for m in json.loads(result.stdout)], ["eDP-1"])

    def test_settled_workspace_reconciliation_does_not_replay_focus_animation(self):
        self.set_monitors([monitor("DP-3", 1, 0, True), monitor("eDP-1", 2, 1920)])
        mocks = LID_MOCKS + '\nreconcile_workspace_ownership() { :; }\n'
        self.shell("main reconcile", script=WORKSPACES, mocks=mocks)
        self.assertNotIn("dispatch", self.log())

    def test_workspace_group_uses_snapshot_from_before_ownership_changes(self):
        self.parked.write_text("eDP-1\n")
        mocks = LID_MOCKS + r'''
reconcile_workspace_ownership() {
    printf '[{"name":"DP-12","x":2256,"y":0,"scale":1,"focused":true,"activeWorkspace":{"id":1}},{"name":"DP-16","x":4816,"y":0,"scale":1,"activeWorkspace":{"id":2}}]' > "$TEST_MONITORS"
}
'''
        self.shell("main reconcile", script=WORKSPACES, mocks=mocks)
        self.assertIn('workspace = "3", on_current_monitor = true', self.log())
        self.assertIn('workspace = "4", on_current_monitor = true', self.log())
        self.assertEqual(self.log().count("monitors -j"), 2)


if __name__ == "__main__":
    unittest.main()
