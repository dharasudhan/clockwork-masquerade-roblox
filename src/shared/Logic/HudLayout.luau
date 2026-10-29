-- HUD layout (pure). Takes the GUI area in px, whether the device is touch-first and whether it
-- is a console / TV (10-foot UI: 5% safe-area inset, bigger scale, no touch buttons but the
-- same action slots shown as button-glyph hints); returns absolute rects { x, y, w, h } (from
-- the top-left) for every element.
-- Lessons from Ghost Mansion's phone playtest: small screens (min axis <= 500) scale the HUD
-- down, the phase timer is a small pill at the top centre, buttons sit LEFT of Roblox's touch
-- jump button (PlayerModule TouchJump geometry), nothing interactive in the thumbstick half.
-- v1.0: floor badge, tappable 3x3 hotbar (+ "?" item info), a small settings gear, lobby menu
-- (Shop / Class / Settings), the kid-friendly guide card, and modal panels (shop, settings,
-- vote, inventory, role card, item card, results, intro dialogue).
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

-- TV safe area (Roblox console guidance: keep UI inside ~5% of each edge)
function HudLayout.safeRect(w: number, h: number, console: boolean?)
	if console then
		return { x = w * 0.05, y = h * 0.05, w = w * 0.9, h = h * 0.9 }
	end
	return { x = 0, y = 0, w = w, h = h }
end

-- Portrait phones (h > w): one column at the top (role chip + floor | minimap, then timer,
-- objective, meter, toast across), the hotbar + compass under it, the action buttons as a column
-- above the jump button (out of the thumbstick zone).
local function portrait(w: number, h: number, touch: boolean)
	local small = math.min(w, h) <= 500
	local s = if small then 0.75 else 1.1
	local L = { small = small, scale = s, touch = touch, console = false, portrait = true, el = {}, group = {} }
	local el, group = L.el, L.group
	local mapS = math.min(w * 0.3, 120 * s)
	el.Minimap = { x = w - mapS - 10, y = 4, w = mapS, h = mapS }
	group.Minimap = "match"
	el.RoleChip = { x = 10, y = 4, w = 150 * s, h = 30 * s }
	el.SettingsMini = { x = el.RoleChip.x + el.RoleChip.w + 6, y = 4, w = 30 * s, h = 30 * s }
	el.FloorBadge = { x = 10, y = el.RoleChip.y + el.RoleChip.h + 4, w = 170 * s, h = 20 * s }
	group.FloorBadge = "match"
	local top = math.max(el.FloorBadge.y + el.FloorBadge.h, el.Minimap.y + mapS) + 6
	local cw = w - 20
	local pillW = math.min(cw, 220 * s)
	el.Timer = { x = (w - pillW) / 2, y = top, w = pillW, h = 30 * s }
	el.Objective = { x = 10, y = el.Timer.y + el.Timer.h + 4, w = cw, h = 20 * s }
	el.Reboot = { x = (w - pillW) / 2, y = el.Objective.y + el.Objective.h + 4, w = pillW, h = 16 * s }
	el.Toast = { x = 10, y = el.Reboot.y + el.Reboot.h + 6, w = cw, h = 24 * s }
	local below = el.Toast.y + el.Toast.h + 8
	local inv = if small then 1 else s
	el.Inventory = { x = 10, y = below, w = 216 * inv, h = 62 * inv }
	group.Inventory = "match"
	local compW = w - (el.Inventory.x + el.Inventory.w) - 16
	el.Compass = { x = w - compW - 10, y = below, w = compW, h = 34 * s }
	group.Compass = "match"
	el.InfoButton = { x = 10, y = el.Inventory.y + el.Inventory.h + 6, w = 32 * inv, h = 32 * inv }
	group.InfoButton = "match"
	el.Guide = { x = el.InfoButton.x + el.InfoButton.w + 6, y = el.InfoButton.y, w = math.min(w - 60, 280 * s), h = 66 * s }
	group.Guide = "match"
	local mw, mh = 132 * s, 38 * s
	for i, n in { "MenuShop", "MenuClass", "MenuSettings" } do
		el[n] = { x = 10, y = below + (i - 1) * (mh + 6), w = mw, h = mh }
		group[n] = "lobby"
	end
	local btn = if small then 60 else 92
	local gap = if small then 10 else 12
	L.button = btn
	local j = HudLayout.jumpRect(w, h)
	local bx = j.x + (j.w - btn) / 2
	for i = 1, 3 do
		el["Button" .. i] = { x = bx, y = j.y - 12 - i * btn - (i - 1) * gap, w = btn, h = btn }
		group["Button" .. i] = "match"
	end
	local colTop = el.Button3.y
	el.Battery = { x = bx - 30 * s, y = colTop - 8 - 14 * s, w = btn + 30 * s, h = 14 * s }
	group.Battery = "match"
	local cardW = math.min(w * 0.9, 460 * s)
	L.modal = {
		RoleCard = { x = (w - cardW) / 2, y = h * 0.25, w = cardW, h = math.min(h * 0.4, 220 * s) },
		Results = { x = w * 0.05, y = h * 0.25, w = w * 0.9, h = math.min(h * 0.45, 300 * s) },
		ItemCard = { x = w * 0.1, y = h * 0.35, w = w * 0.8, h = math.min(h * 0.2, 120 * s) },
		Panel = { x = w * 0.04, y = h * 0.12, w = w * 0.92, h = h * 0.7 },
		Dialogue = { x = w * 0.04, y = h * 0.68, w = w * 0.92, h = math.min(h * 0.24, 170 * s) },
		Banner = { x = (w - cardW) / 2, y = h * 0.4, w = cardW, h = math.min(h * 0.16, 110 * s) },
	}
	return L
end

function HudLayout.compute(w: number, h: number, touch: boolean, console: boolean?)
	if h > w and not console then
		return portrait(w, h, touch)
	end
	local safe = HudLayout.safeRect(w, h, console)
	local X0, Y0, W, H = safe.x, safe.y, safe.w, safe.h
	local minAxis = math.min(w, h)
	local small = minAxis <= 500
	local s = if console then math.clamp(minAxis / 760, 1.2, 1.7)
		elseif small then 0.75
		elseif touch and minAxis >= 700 then 1.15
		else 1
	local L = { small = small, scale = s, touch = touch, console = console == true, el = {}, group = {} }
	local el, group = L.el, L.group
	local pillW, pillH = 220 * s, 30 * s
	el.Timer = { x = X0 + (W - pillW) / 2, y = Y0 + 4, w = pillW, h = pillH }
	local objW = math.min(W * 0.6, 420 * s)
	el.Objective = { x = X0 + (W - objW) / 2, y = el.Timer.y + pillH + 4, w = objW, h = 20 * s }
	el.Reboot = { x = X0 + (W - pillW) / 2, y = el.Objective.y + el.Objective.h + 4, w = pillW, h = 16 * s }
	local toastW = math.min(W * 0.6, 400 * s)
	el.Toast = { x = X0 + (W - toastW) / 2, y = el.Reboot.y + el.Reboot.h + 6, w = toastW, h = 24 * s }
	el.RoleChip = { x = X0 + 10, y = Y0 + 4, w = 150 * s, h = 30 * s }
	el.SettingsMini = { x = el.RoleChip.x + el.RoleChip.w + 6, y = el.RoleChip.y, w = 30 * s, h = 30 * s }
	el.FloorBadge = { x = X0 + 10, y = el.RoleChip.y + el.RoleChip.h + 4, w = 170 * s, h = 20 * s }
	group.FloorBadge = "match"
	-- carried items: 3 x 3 tappable hotbar (9 item kinds); phones keep the full 216 px so labels stay legible
	local inv = if small then 1 else s
	el.Inventory = { x = X0 + 10, y = el.FloorBadge.y + el.FloorBadge.h + 4, w = 216 * inv, h = 62 * inv }
	group.Inventory = "match"
	el.InfoButton = { x = X0 + 10, y = el.Inventory.y + el.Inventory.h + 6, w = 32 * inv, h = 32 * inv }
	group.InfoButton = "match"
	-- the guide card (first match / hints): under the hotbar, never in the thumbstick half
	local gw = math.min(W * 0.34, 280 * s)
	local gh = 66 * s
	el.Guide = { x = el.InfoButton.x + el.InfoButton.w + 6, y = el.InfoButton.y, w = gw, h = gh }
	group.Guide = "match"
	-- lobby menu: SHOP / CLASS / SETTINGS (only in the lobby)
	local mw, mh = 132 * s, 38 * s
	for i, n in { "MenuShop", "MenuClass", "MenuSettings" } do
		el[n] = { x = X0 + 10, y = el.RoleChip.y + el.RoleChip.h + 8 + (i - 1) * (mh + 6), w = mw, h = mh }
		group[n] = "lobby"
	end
	-- minimap (north-up, current floor) + objective compass, top right
	local mapS = if small then 112 else 120 * s
	el.Minimap = { x = X0 + W - mapS - 10, y = Y0 + 4, w = mapS, h = mapS }
	group.Minimap = "match"
	local cw = mapS * 1.35
	el.Compass = { x = X0 + W - cw - 10, y = el.Minimap.y + mapS + 4, w = cw, h = 34 * s }
	group.Compass = "match"
	-- action buttons: a row, rightmost first (touch: left of the jump button; console: glyph hints)
	local btn = if touch then (if small then 60 else 92) elseif console then 64 * s else 72
	local gap = if small then 10 else 12
	local right, bottom
	if touch then
		local j = HudLayout.jumpRect(w, h)
		right, bottom = j.x - 12, j.y + j.h
	else
		right, bottom = X0 + W - 20, Y0 + H - 20
	end
	L.button = btn
	for i = 1, 3 do
		el["Button" .. i] = { x = right - i * btn - (i - 1) * gap, y = bottom - btn, w = btn, h = btn }
		group["Button" .. i] = "match"
	end
	local rowW = 3 * btn + 2 * gap
	el.Battery = { x = right - rowW, y = bottom - btn - 8 - 14 * s, w = rowW, h = 14 * s }
	group.Battery = "match"
	-- modal cards / panels (centre; not part of the overlap check, must fit the safe area)
	local cardW = math.min(W * 0.72, 460 * s)
	local panelW, panelH = math.min(W * 0.86, 680 * s), math.min(H * 0.84, 430 * s)
	local resW, resH = math.min(W * 0.8, 500 * s), math.min(H * 0.8, 280 * s)
	L.modal = {
		RoleCard = { x = X0 + (W - cardW) / 2, y = Y0 + H * 0.22, w = cardW, h = math.min(H * 0.6, 190 * s) },
		Results = { x = X0 + (W - resW) / 2, y = Y0 + (H - resH) / 2, w = resW, h = resH },
		ItemCard = { x = X0 + (W - math.min(W * 0.5, 320 * s)) / 2, y = Y0 + H * 0.3, w = math.min(W * 0.5, 320 * s), h = math.min(H * 0.34, 120 * s) },
		Panel = { x = X0 + (W - panelW) / 2, y = Y0 + (H - panelH) / 2, w = panelW, h = panelH },
		Dialogue = { x = X0 + W * 0.05, y = Y0 + H * 0.66, w = W * 0.9, h = math.min(H * 0.3, 150 * s) },
		Banner = { x = X0 + (W - cardW) / 2, y = Y0 + H * 0.36, w = cardW, h = math.min(H * 0.26, 96 * s) },
	}
	return L
end

function HudLayout.overlaps(a, b): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Problems with a layout: elements off screen (or outside the TV safe area), overlapping each
-- other (elements of the lobby and match groups never show together), or (touch) sitting on
-- the jump button / buttons inside the thumbstick zone. Empty list = good.
function HudLayout.validate(L, w: number, h: number)
	local problems = {}
	local safe = HudLayout.safeRect(w, h, L.console)
	local names = {}
	for name in L.el do
		table.insert(names, name)
	end
	table.sort(names)
	for _, n in names do
		local r = L.el[n]
		if r.x < safe.x - 0.01 or r.y < safe.y - 0.01 or r.x + r.w > safe.x + safe.w + 0.01 or r.y + r.h > safe.y + safe.h + 0.01 then
			table.insert(problems, n .. " off screen")
		end
	end
	for i = 1, #names do
		for j = i + 1, #names do
			local ga, gb = L.group[names[i]], L.group[names[j]]
			local together = ga == nil or gb == nil or ga == gb
			if together and HudLayout.overlaps(L.el[names[i]], L.el[names[j]]) then
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
	for name, m in L.modal do
		if m.x < safe.x - 0.01 or m.y < safe.y - 0.01 or m.x + m.w > safe.x + safe.w + 0.01 or m.y + m.h > safe.y + safe.h + 0.01 then
			table.insert(problems, "modal " .. name .. " off screen")
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
	{ name = "console TV 1920x1080 (safe area)", w = 1920, h = 1080, touch = false, console = true },
	{ name = "phone portrait 390x844", w = 390, h = 844, touch = true },
}

return HudLayout
