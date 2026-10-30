-- Start with the preview hidden; T toggles it back on.
require("toggle-pane"):entry("min-preview")

function Linemode:size_and_mtime()
	local size = self._file:size()
	local time = math.floor(self._file.cha.mtime or 0)
	local modified = "-"

	if time > 0 then
		if os.date("%Y", time) == os.date("%Y") then
			modified = os.date("%b %d %H:%M", time)
		else
			modified = os.date("%b %d  %Y", time)
		end
	end

	return string.format("%8s  %s", size and ya.readable_size(size) or "-", modified)
end

-- Show the current tab's actual sort settings, including changes from default keys.
Header:children_add(function(self)
	local pref = self._tab.pref
	local labels = {
		mtime = "modified",
		btime = "created",
		extension = "extension",
		alphabetical = "name",
		natural = "natural",
		size = "size",
		random = "random",
		none = "none",
	}
	local order = labels[pref.sort_by] or pref.sort_by
	if pref.sort_by ~= "none" and pref.sort_by ~= "random" then
		order = order .. (pref.sort_reverse and " descending" or " ascending")
	end
	local directories = pref.sort_dir_first and " | dirs first" or ""
	return ui.Line(" Sort: " .. order .. directories .. " | F1: help ")
end, 2000, Header.RIGHT)
