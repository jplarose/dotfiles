# Temporary Implementation Plan: Native Workspace Ownership Reconciliation

## Goal

Keep the current topology-relative grouped workspace model while making
Hyprland, rather than generated Waybar state, the source of truth for which
monitor owns every workspace.

## Changes

- Remove the generated per-output Waybar launcher and restore one ordinary
  Waybar instance.
- Keep the lid manager responsible for parking the laptop panel, output power,
  inhibitors, and triggering reconciliation after topology changes.
- In grouped mode, enumerate all positive numeric workspaces and assign each
  to the visible output selected by `(workspace_id - 1) % monitor_count`.
- Restore the requested logical group after the assignments, so docking and
  undocking do not leave a different desktop visible.
- Leave focused mode unchanged: it must not remap all workspaces.

## Acceptance Checks

- With two dock outputs and a parked laptop panel, workspaces 1/3 are owned by
  the first output and 2/4 by the second, including inactive workspaces.
- Normal Waybar shows application-bearing inactive workspaces on their owning
  output without generated configuration or connector-name mappings.
- Dock, undock, re-dock, and closed-lid resume restore the selected group and
  leave no workspace assigned to the parked laptop panel.
