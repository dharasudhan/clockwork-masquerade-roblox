-- Phone-first HUD layout (pure). Takes the GUI area in px and whether the device is
-- touch-first; returns absolute rects { x, y, w, h } (from the top-left) for every element.
-- Lessons from Ghost Mansion's phone playtest: small screens (min axis <= 500) scale the HUD
-- down, the phase timer is a small pill at the top centre, buttons sit LEFT of Roblox's touch
-- jump button (PlayerModule TouchJump geometry), nothing interactive in the thumbstick half.
local HudLayout = {}

-- Roblox touch jump button rect (TouchJump.lua): small screens 70 px at (1,-95)(1,-90);
-- large screens 120 px at (1,-170)(1,-210).
function HudLayout.jumpRect(w: number, h: number)
	if math.min(w, h) <= 500 then
		return { x = w - 95, y = h - 90, w = 70, h = 70 }
	end
	return { x = w - 170, y = h - 210, w = 120, h = 120 }
end

-- Dynamic thumbstick: touches start in the bottom-left area of the screen.
function HudLayout.thumbRect(w: number, h: number)
	return { x = 0, y = h * 0.5, w = w * 0.4, h = h * 0.5 }
end

function HudLayout.compute(w: number, h: number, touch: boolean)
	local minAxis = math.min(w, h)
	local small = minAxis <= 500
	local s = if small then 0.75 elseif touch and minAxis >= 700 then 1.15 else 1
	local L = { small = small, scale = s, touch = touch, el = {} }
	local el = L.el
	local pillW, pillH = 220 * s, 30 * s
	el.Timer = { x = (w - pillW) / 2, y = 4, w = pillW, h = pillH }
	local objW = math.min(w * 0.6, 420 * s)
	el.Objective = { x = (w - objW) / 2, y = el.Timer.y + pillH + 4, w = objW, h = 20 * s }
	el.Reboot = { x = (w - pillW) / 2, y = el.Objective.y + el.Objective.h + 4, w = pillW, h = 16 * s }
	local toastW = math.min(w * 0.6, 400 * s)
	el.Toast = { x = (w - toastW) / 2, y = el.Reboot.y + el.Reboot.h + 6, w = toastW, h = 24 * s }
	el.RoleChip = { x = 10, y = 4, w = 150 * s, h = 30 * s }
	el.Inventory = { x = 10, y = el.RoleChip.y + el.RoleChip.h + 6, w = 150 * s, h = 26 * s }
	-- action buttons: a row, rightmost first
	local btn = if touch then (if small then 60 else 92) else 72
	local gap = if small then 10 else 12
	local right, bottom
	if touch then
		local j = HudLayout.jumpRect(w, h)
		right, bottom = j.x - 12, j.y + j.h
	else
		right, bottom = w - 20, h - 20
	end
	L.button = btn
	for i = 1, 3 do
		el["Button" .. i] = { x = right - i * btn - (i - 1) * gap, y = bottom - btn, w = btn, h = btn }
	end
	local rowW = 3 * btn + 2 * gap
	el.Battery = { x = right - rowW, y = bottom - btn - 8 - 14 * s, w = rowW, h = 14 * s }
	-- modal cards (centre, not part of the overlap check)
	local cardW = math.min(w * 0.7, 420 * s)
	L.modal = {
		RoleCard = { x = (w - cardW) / 2, y = h * 0.3, w = cardW, h = 150 * s },
		Results = {
			x = (w - math.min(w * 0.8, 480 * s)) / 2,
			y = (h - math.min(h * 0.8, 260 * s)) / 2,
			w = math.min(w * 0.8, 480 * s),
			h = math.min(h * 0.8, 260 * s),
		},
	}
	return L
end

function HudLayout.overlaps(a, b): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Problems with a layout: elements off screen, overlapping each other, or (touch) sitting on
-- the jump button / buttons inside the thumbstick zone. Empty list = good.
function HudLayout.validate(L, w: number, h: number)
	local problems = {}
	local names = {}
	for name in L.el do
		table.insert(names, name)
	end
	table.sort(names)
	for _, n in names do
		local r = L.el[n]
		if r.x < 0 or r.y < 0 or r.x + r.w > w + 0.01 or r.y + r.h > h + 0.01 then
			table.insert(problems, n .. " off screen")
		end
	end
	for i = 1, #names do
		for j = i + 1, #names do
			if HudLayout.overlaps(L.el[names[i]], L.el[names[j]]) then
				table.insert(problems, names[i] .. " overlaps " .. names[j])
			end
		end
	end
	if L.touch then
		local jump, thumb = HudLayout.jumpRect(w, h), HudLayout.thumbRect(w, h)
		for _, n in names do
			if HudLayout.overlaps(L.el[n], jump) then
				table.insert(problems, n .. " covers the jump button")
			end
			if string.sub(n, 1, 6) == "Button" and HudLayout.overlaps(L.el[n], thumb) then
				table.insert(problems, n .. " in the thumbstick zone")
			end
		end
	end
	for _, m in L.modal do
		if m.x < 0 or m.y < 0 or m.x + m.w > w + 0.01 or m.y + m.h > h + 0.01 then
			table.insert(problems, "modal off screen")
		end
	end
	return problems
end

HudLayout.TestViewports = {
	{ name = "phone 780x360", w = 780, h = 360, touch = true },
	{ name = "phone 891x411", w = 891, h = 411, touch = true },
	{ name = "phone 2340x1080", w = 2340, h = 1080, touch = true },
	{ name = "tablet 1024x768", w = 1024, h = 768, touch = true },
	{ name = "desktop 1366x768", w = 1366, h = 768, touch = false },
}

return HudLayout
