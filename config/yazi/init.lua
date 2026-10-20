-- Partition a window of files into non-hidden first, hidden last,
-- preserving Yazi's sort order within each group.
local function hidden_last(files)
	local visible, hidden = {}, {}
	for i = 1, #files do
		local f = files[i]
		if f.name:sub(1, 1) == "." then
			hidden[#hidden + 1] = f
		else
			visible[#visible + 1] = f
		end
	end
	local result = {}
	for _, f in ipairs(visible) do result[#result + 1] = f end
	for _, f in ipairs(hidden) do result[#result + 1] = f end
	return result
end

-- Override the current-pane renderer so hidden files appear last.
function Current:redraw()
	local files = self._folder.window
	if #files == 0 then
		return self:empty()
	end

	local sorted = hidden_last(files)

	local left, right = {}, {}
	for _, f in ipairs(sorted) do
		local entity = Entity:new(f)
		left[#left + 1], right[#right + 1] = entity:redraw(), Linemode:new(f):redraw()

		local max = math.max(0, self._area.w - right[#right]:width())
		left[#left]:truncate { max = max, ellipsis = entity:ellipsis(max) }
	end

	return {
		ui.List(left):area(self._area),
		ui.Text(right):area(self._area):align(ui.Align.RIGHT),
	}
end

-- Fix mouse clicks so they target the file at the visual (sorted) position,
-- not the position in Yazi's internal (alphabetical) order.
function Current:click(event, up)
	if up or event.is_middle then
		return
	end

	local y = event.y - self._area.y + 1
	local sorted = hidden_last(self._folder.window)
	if sorted[y] then
		Entity:new(sorted[y]):click(event, up)
	end
end
