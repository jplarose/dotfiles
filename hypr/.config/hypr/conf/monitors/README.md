# Dock monitor ordering

SpecterOps and Framework 13 share the same dock and cabling. Both profiles use
`dock.lua`, which identifies its left and right sockets by DisplayPort MST routes.
The GS27QA monitors both report serial `0x01010101`, and their kernel
`DP-N` connector names can change when the dock reconnects.

The current cabling maps these routes to the layout:

| Dock route | Position | Screen |
| --- | --- | --- |
| `2-2` | `2256x0` | Left |
| `4-4` | `4816x0` | Right |

`conf/monitor.lua` coalesces config load, session startup, monitor connection,
disconnection, and layout events for 500 ms. It runs `scripts/dock-monitors.py`
before the lid manager, which then updates workspace ownership. The helper reads
the immutable DRM `PATH` property through `modetest`, resolves each route to its
current output name, and applies only necessary layout changes. It detects the
driver on a host with one graphics card (AMD or Intel), retries partial/transient
dock enumeration, and waits for applied positions before returning. Running the
query in a separate process avoids blocking Hyprland. If route resolution fails,
the lid manager still runs to recover the laptop panel; errors go to stderr.

For example, `mst:3-2-2` means upstream connector `3`, then dock ports `2-2`.
Only the dock portion is configured, so the upstream connector may change.
The helper requires the expected monitor model, rejects duplicate route matches
and matches spanning different upstream connectors, and leaves unknown outputs
to the default Hyprland rule. It can position either dock display independently
when only one is connected.

This identifies sockets, not individual monitors. Keep each monitor cable in its
assigned dock socket. Changing the dock, its internal topology, or those cable
connections requires updating the route mapping once. It cannot distinguish two
different docks that expose the same routes and monitor models.

Dependencies: Python 3 and `modetest` from libdrm, with access to the graphics
device as the logged-in desktop user. Install the `hypr` stow package after adding
the helper and shared profile so they are available under `~/.config/hypr/`.
For a host with multiple graphics cards, set an explicit driver in its profile;
automatic selection refuses to guess between cards.

To inspect the current mapping without changing displays:

```sh
python3 ~/.config/hypr/scripts/dock-monitors.py --driver auto --model GS27QA \
  --port 2-2=2256x0 --port 4-4=4816x0 --dry-run
```

The route mechanism is documented by the kernel's
[DRM PATH property](https://docs.kernel.org/gpu/drm-kms.html).
Physical reconnect and reboot checks are still needed to confirm this dock's
firmware preserves the routes across those events.

## Lid and dock transitions

| State | Panel policy | Workspace policy |
| --- | --- | --- |
| Lid open, dock connected | Panel and external displays on | All visible displays participate |
| Lid closed, dock connected | Panel enabled but blanked; dock awake | Panel excluded; external displays participate |
| Lid open, dock disconnected | Panel enabled and on | Workspaces return to the panel |
| Lid closed, dock disconnected | Lock and blank panel; release dock sleep inhibitor | Panel is unparked; idle suspend remains available |

The panel stays enabled in Hyprland to avoid falling into its synthetic
`FALLBACK` output when the dock disappears. `FALLBACK` is never counted as an
external dock display. Resume wakes external displays and only lights the panel
if its lid is open.

`hypr-lid-manager` serializes transitions instead of dropping events while busy.
Its watcher checks hardware lid state and output geometry every two seconds,
retries failed reconciliations, and is restarted when the script/session changes.
It deliberately ignores DPMS changes so idle blanking does not immediately wake
the laptop. The workspace manager uses a single topology snapshot and selects
the logical group before moving ownership; a stale parked marker cannot hide
the last remaining panel.

`SUPER+SHIFT+P` reruns dock/lid/workspace reconciliation. `SUPER+CTRL+P` restores
the laptop panel manually. Inspect the policy with `hypr-lid-manager status`.

Run the automated transition and dock-route tests from the repository root:

```sh
python3 -B -m unittest discover -s tests -v
```

The tests mock hardware, IPC, locking contention, and asynchronous dock readiness.
On each laptop, also check real cable removal/reconnection with the lid open and
closed, followed by opening the lid while undocked. Framework's actual driver and
port routes require that hardware check; they cannot be queried from SpecterOps.
