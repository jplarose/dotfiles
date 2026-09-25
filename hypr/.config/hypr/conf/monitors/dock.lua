-- The shared dock: MST route 2-2 is left and route 4-4 is right.
-- eDP-1 remains at the origin and is parked by hypr-lid-manager when closed.
return "python3 ~/.config/hypr/scripts/dock-monitors.py"
	.. " --driver auto --model GS27QA"
	.. " --port 2-2=2256x0 --port 4-4=4816x0 --settle"
