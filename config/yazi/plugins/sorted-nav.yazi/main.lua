-- Reorder a file list so non-hidden entries come first, hidden (dotfile)
-- entries last, preserving Yazi's native order within each group.
local function hidden_last(files)
	local vis, hid = {}, {}
	for i = 1, #files do
		local f = files[i]
		if f.name:sub(1, 1) == "." then
			hid[#hid + 1] = f
		else
			vis[#vis + 1] = f
		end
	end
	local out = {}
	for _, f in ipairs(vis) do out[#out + 1] = f end
	for _, f in ipairs(hid) do out[#out + 1] = f end
	return out
end

-- Runs in the SYNC context (where `cx` is available). Given a direction,
-- returns how many rows to move in Yazi's internal order to land on the
-- next/prev entry in the visual (hidden-last) order.
local compute = ya.sync(function(state, dir)
	local folder = cx.active.current
	if not folder then return 0 end

	local all = {}
	for i = 1, #folder.files do all[i] = folder.files[i] end
	if #all == 0 then return 0 end

	-- url -> internal index
	local internal = {}
	for i, f in ipairs(all) do internal[tostring(f.url)] = i end

	local hovered = folder.hovered
	if not hovered then return 0 end
	local hov_url = tostring(hovered.url)
	local hov_internal = internal[hov_url]
	if not hov_internal then return 0 end

	local sorted = hidden_last(all)
	local hov_sorted
	for i, f in ipairs(sorted) do
		if tostring(f.url) == hov_url then
			hov_sorted = i
			break
		end
	end
	if not hov_sorted then return 0 end

	local tgt_sorted
	if dir == "first" then
		tgt_sorted = 1
	elseif dir == "last" then
		tgt_sorted = #sorted
	elseif dir == "down" then
		tgt_sorted = math.min(hov_sorted + 1, #sorted)
	else
		tgt_sorted = math.max(hov_sorted - 1, 1)
	end

	local tgt_internal = internal[tostring(sorted[tgt_sorted].url)]
	if not tgt_internal then return 0 end
	return tgt_internal - hov_internal
end)

return {
	entry = function(self, job)
		local dir = tostring(job.args[1] or "down")
		local delta = compute(dir)
		if delta and delta ~= 0 then
			ya.emit("arrow", { delta })
		end
	end,
}
