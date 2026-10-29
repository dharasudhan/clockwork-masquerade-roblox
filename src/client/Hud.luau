-- Phone / desktop / console HUD (v1.0): role chip + settings gear, floor badge ("B1 BOILER
-- LEVEL", "GROUND FLOOR", "1ST FLOOR", "2ND FLOOR ATTIC", "3RD FLOOR TOWER"), phase timer pill,
-- objective line, night meter (grid reboot / pages / keys / dawn ring), toasts, a tappable 3x3
-- hotbar with big item icons + slot numbers + the selected item's one-line tip, an "?" items
-- panel button, the guide card (tutorial / hints), the lantern battery, up to 3 context buttons
-- with button-glyph hints (touch: left of the jump button; gamepad/keyboard: glyph hints), the
-- minimap + compass, the lobby menu (Shop / Class / Settings), and the modal cards (kid-friendly
-- role card, item card, night/dawn banner, ink splash, results). Rects come from Logic/HudLayout.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared.Logic.HudLayout)
local Nights = require(Shared.Config.Nights)
local Gadgets = require(Shared.Config.Gadgets)
local Style = require(Shared.Config.Style)
local Items = require(Shared.Config.Items)
local Manor = require(Shared.Config.Manor)
local ManorLayout = require(Shared.Logic.ManorLayout)
local State = require(script.Parent.State)
local Minimap = require(script.Parent.Minimap)
local Input = require(script.Parent.Input)

local Hud = {}

local function rgb(name: string): Color3
	local c = Style.Palette[name] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end
Hud.rgb = rgb

local gui: ScreenGui = nil :: any
local el: { [string]: any } = {}
local modal: { [string]: any } = {}
local buttonActions: { string? } = {}
local buttonItems: { string? } = {}
local onButton: ((string, string?) -> ())? = nil
local lastLayoutKey = ""
local layout: any = nil
local forceConsole: boolean? = nil
local slotItems: { string } = {} -- hotbar slot -> item id (visible chips in order)

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thick: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thick
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(name: string, parent: Instance, text: string?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = rgb("Cream")
	l.Text = text or ""
	l.Parent = parent
	return l
end
Hud.label = label

local function panel(name: string, color: string, transparency: number?, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = rgb(color)
	f.BackgroundTransparency = transparency or 0.15
	f.BorderSizePixel = 0
	f.Parent = parent or gui
	corner(f, 8)
	return f
end
Hud.panel = panel

local function bar(name: string, color: string, fillColor: string): Frame
	local f = panel(name, color, 0.2)
	stroke(f, rgb("Brass"), 1)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = rgb(fillColor)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = f
	corner(fill, 8)
	local t = label("Text", f)
	t.ZIndex = 2
	t.TextStrokeTransparency = 0.5
	return f
end

local function textButton(name: string, text: string, color: string?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = rgb(color or "Copper")
	b.BackgroundTransparency = 0.05
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = rgb("Cream")
	b.Text = text
	b.Selectable = true
	b.Parent = gui
	corner(b, 10)
	stroke(b, rgb("Brass"), 2)
	return b
end
Hud.textButton = textButton

-- a small glyph chip in a button's corner ("RT", "Y", "F" ...; gamepad: the Roblox glyph image)
local function glyphChip(parent: Instance)
	local g = Instance.new("Frame")
	g.Name = "Glyph"
	g.AnchorPoint = Vector2.new(1, 0)
	g.Position = UDim2.fromScale(1.02, -0.06)
	g.Size = UDim2.fromScale(0.42, 0.34)
	g.BackgroundColor3 = rgb("Coal")
	g.BackgroundTransparency = 0.15
	g.BorderSizePixel = 0
	g.Visible = false
	g.ZIndex = 4
	g.Parent = parent
	corner(g, 6)
	local t = label("Text", g)
	t.ZIndex = 5
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Fit
	img.Visible = false
	img.ZIndex = 5
	img.Parent = g
	return g
end

local function setGlyph(chip: Frame, action: string?)
	local text, image = nil, nil
	if action then
		text, image = Input.glyph(action)
	end
	chip.Visible = text ~= nil
	if text then
		local img = chip:FindFirstChild("Image") :: ImageLabel
		local hasImg = type(image) == "string" and image ~= ""
		img.Visible = hasImg
		img.Image = if hasImg then image :: string else ""
		;(chip:FindFirstChild("Text") :: TextLabel).Text = if hasImg then "" else text
	end
end

function Hud.build(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "ClockworkHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	el.Timer = panel("Timer", "WalnutDark", 0.1)
	stroke(el.Timer, rgb("Brass"), 2)
	corner(el.Timer, 40)
	label("Text", el.Timer).TextColor3 = rgb("Brass")
	el.Objective = panel("Objective", "TealDeep", 0.35)
	label("Text", el.Objective)
	el.Reboot = bar("Reboot", "Iron", "TealNeon")
	el.Toast = panel("Toast", "WalnutDark", 0.25)
	label("Text", el.Toast)
	el.RoleChip = panel("RoleChip", "TealDeep", 0.1)
	stroke(el.RoleChip, rgb("Brass"), 1.5)
	label("Text", el.RoleChip)
	el.SettingsMini = textButton("SettingsMini", "⚙", "WalnutDark")
	el.SettingsMini.Activated:Connect(function()
		if onButton then
			onButton("menu", "Settings")
		end
	end)
	el.FloorBadge = panel("FloorBadge", "Coal", 0.25)
	stroke(el.FloorBadge, rgb("Brass"), 1)
	local fl = label("Text", el.FloorBadge)
	fl.TextColor3 = rgb("Amber")
	-- hotbar: 9 tappable chips (big emoji icon + short name + slot number / glyph)
	el.Inventory = panel("Inventory", "WalnutDark", 0.3)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / 3, -2, 1 / 3, -2)
	grid.CellPadding = UDim2.fromOffset(2, 2)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = el.Inventory
	for i, item in Items.Order do
		local def = Items.Defs[item]
		local chip = Instance.new("TextButton")
		chip.Name = item
		chip.LayoutOrder = i
		chip.Text = ""
		chip.AutoButtonColor = true
		chip.Selectable = true
		chip.BackgroundColor3 = rgb("Iron")
		chip.BackgroundTransparency = 0.1
		chip.BorderSizePixel = 0
		chip.Visible = false
		chip.Parent = el.Inventory
		corner(chip, 5)
		local sel = Instance.new("UIStroke")
		sel.Name = "SelOutline"
		sel.Color = rgb("TealNeon")
		sel.Thickness = 2
		sel.Enabled = false
		sel.Parent = chip
		local icon = label("Icon", chip, def.icon or "?")
		icon.Size = UDim2.fromScale(0.36, 1)
		icon.Font = Enum.Font.GothamBold
		local tint = Instance.new("Frame")
		tint.Name = "Tint"
		tint.BackgroundColor3 = rgb(def.color)
		tint.BorderSizePixel = 0
		tint.Size = UDim2.fromScale(0.06, 0.8)
		tint.Position = UDim2.fromScale(0.36, 0.1)
		tint.Parent = chip
		local l = label("Label", chip, def.short)
		l.Size = UDim2.fromScale(0.54, 0.7)
		l.Position = UDim2.fromScale(0.44, 0)
		local n = label("Slot", chip, "")
		n.Size = UDim2.fromScale(0.54, 0.32)
		n.Position = UDim2.fromScale(0.44, 0.66)
		n.TextColor3 = rgb("Brass")
		n.Font = Enum.Font.Gotham
		chip.Activated:Connect(function()
			if onButton then
				onButton("select", item)
			end
		end)
	end
	local tip = label("Tip", el.Inventory, "")
	tip.Name = "Tip"
	tip.Size = UDim2.new(1.7, 0, 0.26, 0)
	tip.Position = UDim2.fromScale(0, 1.02)
	tip.TextXAlignment = Enum.TextXAlignment.Left
	tip.TextColor3 = rgb("Cream2")
	tip.TextStrokeTransparency = 0.4
	tip.Font = Enum.Font.GothamMedium
	tip.Visible = false
	el.InfoButton = textButton("InfoButton", "?", "TealDeep")
	el.InfoButton.Activated:Connect(function()
		if onButton then
			onButton("info")
		end
	end)
	el.Guide = panel("Guide", "Coal", 0.12)
	stroke(el.Guide, rgb("Amber"), 2)
	local gi = label("Icon", el.Guide, "")
	gi.Size = UDim2.fromScale(0.26, 1)
	local gt = label("Text", el.Guide, "")
	gt.Size = UDim2.fromScale(0.72, 0.62)
	gt.Position = UDim2.fromScale(0.27, 0.04)
	gt.TextXAlignment = Enum.TextXAlignment.Left
	gt.TextColor3 = rgb("Amber")
	gt.Font = Enum.Font.GothamBlack
	local gs = label("Sub", el.Guide, "")
	gs.Size = UDim2.fromScale(0.72, 0.32)
	gs.Position = UDim2.fromScale(0.27, 0.64)
	gs.TextXAlignment = Enum.TextXAlignment.Left
	gs.Font = Enum.Font.GothamMedium
	el.Guide.Visible = false
	-- lobby menu
	for n, txt in { MenuShop = "🛒 SHOP", MenuClass = "🔧 CLASS", MenuSettings = "⚙ SETTINGS" } do
		local b = textButton(n, txt, if n == "MenuShop" then "Copper" else "TealDeep")
		b.Visible = false
		b.Activated:Connect(function()
			if onButton then
				onButton("menu", string.sub(n, 5))
			end
		end)
		el[n] = b
	end
	el.Minimap = panel("Minimap", "WalnutDark", 0.25)
	stroke(el.Minimap, rgb("Brass"), 1.5)
	el.Minimap.ClipsDescendants = true
	el.Compass = panel("Compass", "TealDeep", 0.2)
	stroke(el.Compass, rgb("Brass"), 1)
	Minimap.build(el.Minimap, el.Compass)
	el.Battery = bar("Battery", "Iron", "Warm")
	for i = 1, 3 do
		local b = Instance.new("TextButton")
		b.Name = "Button" .. i
		b.BackgroundColor3 = rgb("Copper")
		b.BackgroundTransparency = 0.05
		b.AutoButtonColor = true
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = rgb("Cream")
		b.Text = ""
		b.Visible = false
		b.Selectable = false
		b.Parent = gui
		corner(b, 40)
		stroke(b, rgb("Brass"), 2)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.12, 0)
		pad.PaddingRight = UDim.new(0.12, 0)
		pad.Parent = b
		local cd = Instance.new("Frame")
		cd.Name = "Cooldown"
		cd.BackgroundColor3 = Color3.new(0, 0, 0)
		cd.BackgroundTransparency = 0.45
		cd.BorderSizePixel = 0
		cd.Size = UDim2.fromScale(1, 0)
		cd.AnchorPoint = Vector2.new(0, 1)
		cd.Position = UDim2.fromScale(0, 1)
		cd.Parent = b
		corner(cd, 40)
		glyphChip(b)
		b.Activated:Connect(function()
			local a = buttonActions[i]
			if a and onButton then
				onButton(a, buttonItems[i])
			end
		end)
		el["Button" .. i] = b
	end
	-- ---- modal cards ----
	modal.RoleCard = panel("RoleCard", "WalnutDark", 0.05)
	stroke(modal.RoleCard, rgb("Brass"), 3)
	local t = label("Title", modal.RoleCard)
	t.Size = UDim2.fromScale(0.96, 0.26)
	t.Position = UDim2.fromScale(0.02, 0.02)
	t.Font = Enum.Font.Sarpanch
	for k = 1, 3 do
		local line = label("Line" .. k, modal.RoleCard)
		line.Size = UDim2.fromScale(0.9, 0.2)
		line.Position = UDim2.fromScale(0.05, 0.28 + (k - 1) * 0.22)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Font = Enum.Font.GothamBold
	end
	modal.RoleCard.Visible = false
	modal.ItemCard = panel("ItemCard", "Coal", 0.05)
	stroke(modal.ItemCard, rgb("Amber"), 3)
	local ii = label("Icon", modal.ItemCard)
	ii.Size = UDim2.fromScale(0.3, 1)
	local iname = label("ItemName", modal.ItemCard)
	iname.Size = UDim2.fromScale(0.66, 0.45)
	iname.Position = UDim2.fromScale(0.32, 0.06)
	iname.TextXAlignment = Enum.TextXAlignment.Left
	iname.TextColor3 = rgb("Amber")
	iname.Font = Enum.Font.GothamBlack
	local ikid = label("Kid", modal.ItemCard)
	ikid.Size = UDim2.fromScale(0.66, 0.4)
	ikid.Position = UDim2.fromScale(0.32, 0.54)
	ikid.TextXAlignment = Enum.TextXAlignment.Left
	modal.ItemCard.Visible = false
	modal.Banner = panel("Banner", "Coal", 0.1)
	stroke(modal.Banner, rgb("Brass"), 3)
	local bt = label("Title", modal.Banner)
	bt.Size = UDim2.fromScale(0.96, 0.55)
	bt.Position = UDim2.fromScale(0.02, 0.04)
	bt.Font = Enum.Font.Sarpanch
	bt.TextColor3 = rgb("Brass")
	local bs = label("Sub", modal.Banner)
	bs.Size = UDim2.fromScale(0.96, 0.36)
	bs.Position = UDim2.fromScale(0.02, 0.6)
	modal.Banner.Visible = false
	modal.Results = panel("Results", "WalnutDark", 0.05)
	stroke(modal.Results, rgb("Brass"), 3)
	local rt = label("Title", modal.Results)
	rt.Size = UDim2.fromScale(1, 0.22)
	rt.Font = Enum.Font.Sarpanch
	local rr = label("Reason", modal.Results)
	rr.Size = UDim2.fromScale(0.9, 0.13)
	rr.Position = UDim2.fromScale(0.05, 0.22)
	local rn = label("Nights", modal.Results)
	rn.Size = UDim2.fromScale(0.9, 0.12)
	rn.Position = UDim2.fromScale(0.05, 0.36)
	rn.TextColor3 = rgb("Brass")
	local ry = label("You", modal.Results)
	ry.Size = UDim2.fromScale(0.9, 0.16)
	ry.Position = UDim2.fromScale(0.05, 0.5)
	local rl = label("Roster", modal.Results)
	rl.Size = UDim2.fromScale(0.9, 0.26)
	rl.Position = UDim2.fromScale(0.05, 0.7)
	rl.Font = Enum.Font.Gotham
	modal.Results.Visible = false
	-- ink splash (Night 2 trapped cabinet): full screen, on top
	local ink = Instance.new("Frame")
	ink.Name = "Ink"
	ink.Size = UDim2.fromScale(1, 1)
	ink.BackgroundColor3 = rgb("Coal")
	ink.BackgroundTransparency = 0.12
	ink.BorderSizePixel = 0
	ink.Visible = false
	ink.ZIndex = 20
	ink.Parent = gui
	for k = 1, 6 do
		local blob = Instance.new("Frame")
		blob.Name = "Blob"
		blob.BackgroundColor3 = rgb("Navy")
		blob.BorderSizePixel = 0
		blob.Position = UDim2.fromScale(0.1 + (k * 0.137) % 0.7, 0.15 + (k * 0.29) % 0.6)
		blob.Size = UDim2.fromScale(0.18, 0.24)
		blob.ZIndex = 21
		blob.Parent = ink
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = blob
	end
	local inkText = label("Text", ink, "INK! A trapped cabinet!")
	inkText.Size = UDim2.fromScale(0.6, 0.12)
	inkText.Position = UDim2.fromScale(0.2, 0.44)
	inkText.ZIndex = 22
	modal.Ink = ink
	return gui
end

function Hud.onButton(cb: (string, string?) -> ())
	onButton = cb
end

function Hud.gui(): ScreenGui
	return gui
end

function Hud.layout()
	return layout
end

function Hud.setConsole(on: boolean?)
	forceConsole = on
	lastLayoutKey = ""
end

-- Positions every element for a w x h GUI area.
function Hud.applyLayout(w: number, h: number, touch: boolean, console: boolean?)
	local L = HudLayout.compute(w, h, touch, console)
	layout = L
	for name, r in L.el do
		local o = el[name]
		if o then
			o.AnchorPoint = Vector2.new(0, 0)
			o.Position = UDim2.fromOffset(math.floor(r.x), math.floor(r.y))
			o.Size = UDim2.fromOffset(math.floor(r.w), math.floor(r.h))
		end
	end
	for name, r in L.modal do
		local o = modal[name]
		if o then
			o.Position = UDim2.fromOffset(math.floor(r.x), math.floor(r.y))
			o.Size = UDim2.fromOffset(math.floor(r.w), math.floor(r.h))
		end
	end
	return L
end

local function viewport(): (number, number)
	local okAbs, abs = pcall(function()
		return gui and gui.AbsoluteSize
	end)
	if okAbs and abs and abs.X > 0 and abs.Y > 0 then
		return abs.X, abs.Y
	end
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1024, 768)
	return v.X, v.Y
end

local function fmt(t: number): string
	t = math.max(0, math.ceil(t))
	return string.format("%d:%02d", t // 60, t % 60)
end

local PhaseName = { Lobby = "LOBBY", Day = "DAY", Night = "NIGHT", Results = "RESULTS", Dawn = "DAWN" }

-- Items the player can use right now (held, has a use, allowed in this phase), in cycle order.
function Hud.usableItems(phase: string, attrs): { string }
	local out = {}
	for _, id in Items.Order do
		local def = Items.Defs[id]
		if def.use and (attrs[id] or 0) > 0 and Items.usableIn(id, phase) then
			table.insert(out, id)
		end
	end
	return out
end

-- The selected item, kept valid: a stale pick falls back to the first usable item; at night a
-- low lantern pre-selects the dry-cell.
function Hud.resolveSelected(phase: string, attrs, selected: string?): string?
	local list = Hud.usableItems(phase, attrs)
	if #list == 0 then
		return nil
	end
	if phase == "Night" and (attrs.Battery or 0) < Gadgets.Lantern.batteryMax * 0.2 and table.find(list, "DryCell") then
		return "DryCell"
	end
	if selected and table.find(list, selected) then
		return selected
	end
	return list[1]
end

-- the hotbar slots (held items in Items order); slot n -> item id
function Hud.slots(attrs): { string }
	local out = {}
	for _, id in Items.Order do
		if (attrs[id] or 0) > 0 then
			table.insert(out, id)
		end
	end
	return out
end

local GadgetText = { barricade = "GATE", strobe = "FLASH", glide = "GLIDE", dash = "DASH" } -- short: legible on a 60 px phone button

-- What the GADGET button does for this client (mirrors AbilityService.kind on the server).
function Hud.gadgetKind(phase: string, who: string?, attrs): string?
	if phase ~= "Night" then
		return nil
	end
	if who == "Guest" then
		local c = Gadgets.Classes[attrs.PClass or "Mechanist"]
		return c and c.gadget
	elseif who == "Phantom" then
		local n = workspace:GetAttribute("CM_Night")
		if n == 2 then
			return "glide"
		elseif n == 3 and workspace:GetAttribute("CM_Stage") == "Overdrive" then
			return "dash"
		end
	end
	return nil
end

-- Context buttons (max 3): { action, text, readyAt?, cooldown?, on?, dim?, glyph? }
function Hud.buttonsFor(phase: string, who: string?, attrs, selected: string?): { any }
	local out = {}
	if who == nil or (phase ~= "Night" and phase ~= "Day") then
		return out
	end
	local looksGuest = who == "Guest" or (who == "Phantom" and phase == "Day")
	if who == "Guest" and phase == "Night" then
		table.insert(out, { action = "lantern", text = if attrs.LanternOn then "LAMP ON" else "LAMP", on = attrs.LanternOn == true, glyph = "primary" })
	end
	if looksGuest then
		local list = Hud.usableItems(phase, attrs)
		local sel = Hud.resolveSelected(phase, attrs, selected)
		if sel then
			local def = Items.Defs[sel]
			table.insert(out, { action = "use", item = sel, text = (def.icon or "") .. " " .. (attrs[sel] or 0), readyAt = attrs["ReadyAt_" .. sel], cooldown = def.cooldown, glyph = "use" })
		elseif phase == "Night" then
			table.insert(out, { action = "use", text = "NO ITEM", dim = true, glyph = "use" })
		end
		local g = Hud.gadgetKind(phase, who, attrs)
		if g then
			local c = Gadgets.Classes[attrs.PClass or "Mechanist"]
			table.insert(out, { action = "gadget", text = GadgetText[g], readyAt = attrs.GadgetReadyAt, cooldown = c and c.cooldown or 30, glyph = "gadget" })
		elseif #list > 1 then
			table.insert(out, { action = "next", text = "NEXT", glyph = "next" })
		end
	elseif who == "Phantom" then
		table.insert(out, { action = "tag", text = "TAG", readyAt = attrs.TagReadyAt, cooldown = Gadgets.Phantom.tagCooldown, glyph = "primary" })
		local g = Hud.gadgetKind(phase, who, attrs)
		if g then
			local n = Nights[workspace:GetAttribute("CM_Night") or 1]
			local cd = if g == "glide" then (n.phaseGlide and n.phaseGlide.cooldown or 25) else (n.finale and n.finale.dash.cooldown or 12)
			table.insert(out, { action = "gadget", text = GadgetText[g], readyAt = attrs.GadgetReadyAt, cooldown = cd, glyph = "gadget" })
		end
	elseif who == "Wisp" then
		table.insert(out, { action = "flicker", text = "FLICKER", readyAt = attrs.FlickerReadyAt, cooldown = Gadgets.Wisp.flickerCooldown, glyph = "primary" })
		table.insert(out, { action = "slick", text = "SLICK", readyAt = attrs.SlickReadyAt, cooldown = Gadgets.Wisp.slickCooldown, glyph = "gadget" })
	end
	return out
end

function Hud.objective(phase: string, who: string?): string
	if phase == "Lobby" then
		return "The masquerade begins soon - bots fill up to 6 guests"
	elseif phase == "Results" then
		return "Back to the terrace in a moment..."
	elseif phase == "Dawn" then
		return "Dawn break - the next night is coming"
	end
	if who == nil then
		return "Masquerade in progress - you join the next one"
	end
	local n = Nights[workspace:GetAttribute("CM_Night") or 1] or Nights[1]
	local key = if workspace:GetAttribute("CM_Stage") == "Overdrive" and n.objective.Overdrive then "Overdrive" else phase
	local byPhase = n.objective[key] or {}
	return byPhase[who] or byPhase.Guest or ""
end

-- The night meter: grid reboot (+ pages on Night 2), keys (Showdown), dawn ring (Overdrive).
function Hud.meter(phase: string): (boolean, number, string)
	if phase ~= "Night" then
		return false, 0, ""
	end
	local stage = workspace:GetAttribute("CM_Stage")
	if stage == "Overdrive" then
		local ring, need = workspace:GetAttribute("CM_Ring") or 0, workspace:GetAttribute("CM_RingNeed") or 40
		return true, ring / math.max(1, need), string.format("DAWN RING %d / %d s", math.floor(ring), need)
	elseif stage == "Showdown" then
		local keys = workspace:GetAttribute("CM_Keys") or ""
		local n = if keys == "" then 0 else #string.split(keys, ",")
		return true, n / 3, string.format("KEYS %d / 3  🗝️", n)
	end
	local reboot = workspace:GetAttribute("CM_Reboot") or 0
	local text = string.format("GRID REBOOT %d%%", math.floor(reboot))
	local need = workspace:GetAttribute("CM_PagesNeed") or 0
	if need > 0 then
		text ..= string.format("  ·  PAGES %d/%d", workspace:GetAttribute("CM_Pages") or 0, need)
	end
	return true, reboot / 100, text
end

function Hud.floorText(): string
	local me = Players.LocalPlayer
	local c = me and me.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return ""
	end
	local pos = r.CFrame.Position
	if not ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z) then
		return "OUTSIDE"
	end
	return Minimap.floorShort(ManorLayout.levelAt(Manor, pos.Y))
end

local function isConsole(): boolean
	if forceConsole ~= nil then
		return forceConsole
	end
	local ok, tenFoot = pcall(function()
		return GuiService:IsTenFootInterface()
	end)
	return ok and tenFoot == true
end

function Hud.update()
	if not gui then
		return
	end
	local w, h = viewport()
	local okTouch, touch = pcall(function()
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end)
	touch = okTouch and touch == true
	local console = isConsole()
	local key = string.format("%dx%d%s%s", w, h, tostring(touch), tostring(console))
	if key ~= lastLayoutKey then
		lastLayoutKey = key
		Hud.applyLayout(w, h, touch, console)
	end
	local phase = State.phase()
	local who = State.who()
	local now = workspace:GetServerTimeNow()
	local me = Players.LocalPlayer
	local attrs = if me then me:GetAttributes() else {}
	local inMatchPhase = phase == "Day" or phase == "Night"
	-- timer pill (+ night n of 3)
	local nightNo = workspace:GetAttribute("CM_NightNo")
	local prefix = if (inMatchPhase or phase == "Dawn") and nightNo then string.format("N%d/%d ", nightNo, workspace:GetAttribute("CM_NightCount") or 3) else ""
	el.Timer.Text.Text = prefix .. (PhaseName[phase] or phase) .. "  " .. fmt(State.timeLeft())
	-- objective (a channel in progress overrides it)
	local obj = Hud.objective(phase, who)
	local ch = State.channel
	if ch and ch.channel == "Tamper" and ch.seconds then
		obj = string.format("Tampering... stand still (%.1f s)", math.max(0, ch.seconds - (now - ch.startedAt)))
	elseif attrs.Repairing then
		obj = "Repairing breaker " .. tostring(attrs.Repairing) .. "... stand still"
	elseif attrs.Slowed then
		obj = "Oil slick! You're slowed"
	elseif attrs.CarryKey then
		obj = "You have a KEY! Run to the Exit Console (Ballroom)!"
	elseif (attrs.Pages or 0) > 0 and phase == "Night" then
		obj = "Bring your page to the Projector (Library)!"
	elseif attrs.FrozenUntil and now < attrs.FrozenUntil then
		obj = "FROZEN!"
	end
	el.Objective.Text.Text = obj
	-- night meter
	local show, frac, mtext = Hud.meter(phase)
	el.Reboot.Visible = show
	el.Reboot.Fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	el.Reboot.Text.Text = mtext
	-- role chip
	local chipText, chipColor = "TERRACE", "TealDeep"
	if who == "Guest" then
		local c = Gadgets.Classes[attrs.PClass or ""]
		chipText, chipColor = (if c then c.icon .. " " else "") .. "GUEST", "TealDeep"
	elseif who == "Phantom" then
		chipText, chipColor = if phase == "Day" then "PHANTOM (secret)" else "PHANTOM", "Velvet"
	elseif who == "Wisp" or who == "Bubble" then
		chipText, chipColor = "ELECTRO-WISP", "Iron"
	elseif phase ~= "Lobby" then
		chipText = "SPECTATING"
	else
		chipText = string.format("LV %d  ⚙ %d", attrs.Level or 1, attrs.GearTokens or 0)
	end
	el.RoleChip.Text.Text = chipText
	el.RoleChip.BackgroundColor3 = rgb(chipColor)
	-- floor badge
	el.FloorBadge.Visible = inMatchPhase and who ~= nil
	if el.FloorBadge.Visible then
		el.FloorBadge.Text.Text = Hud.floorText()
	end
	-- hotbar + battery
	local showItems = who == "Guest" or (who == "Phantom" and phase == "Day")
	el.Inventory.Visible = showItems
	el.InfoButton.Visible = showItems
	State.selected = Hud.resolveSelected(phase, attrs, State.selected)
	slotItems = Hud.slots(attrs)
	local glyphMode = Input.device() ~= "touch"
	for _, id in Items.Order do
		local chip = el.Inventory[id]
		local n = attrs[id] or 0
		chip.Visible = n > 0
		chip.Label.Text = Items.Defs[id].short .. (if n > 1 then " " .. n else "")
		chip.SelOutline.Enabled = State.selected == id or (State.selected == nil and State.picked == id)
		local slot = table.find(slotItems, id)
		chip.Slot.Text = if slot and glyphMode then tostring(slot) else ""
	end
	local tipId = State.selected or State.picked
	local hints = attrs.Set_Hints ~= false
	el.Inventory.Tip.Visible = showItems and hints and tipId ~= nil and (attrs[tipId] or 0) > 0
	if tipId and Items.Defs[tipId] then
		el.Inventory.Tip.Text = (Items.Defs[tipId].icon or "") .. " " .. Items.Defs[tipId].kid
	end
	local battery = attrs.Battery or 0
	el.Battery.Visible = showItems and phase == "Night"
	el.Battery.Fill.Size = UDim2.fromScale(math.clamp(battery / Gadgets.Lantern.batteryMax, 0, 1), 1)
	el.Battery.Text.Text = string.format("LANTERN %ds", math.floor(battery))
	-- toast
	local toast = State.toast
	el.Toast.Visible = toast ~= nil and os.clock() - toast.at < 3.5
	if toast then
		el.Toast.Text.Text = toast.text
		el.Toast.Text.TextColor3 = rgb(toast.color or "Cream")
	end
	-- buttons
	local btns = Hud.buttonsFor(phase, who, attrs, State.selected)
	for i = 1, 3 do
		local b = el["Button" .. i]
		local spec = btns[i]
		buttonActions[i] = spec and spec.action
		buttonItems[i] = spec and spec.item
		b.Visible = spec ~= nil
		if spec then
			b.Text = spec.text
			b.BackgroundColor3 = rgb(if spec.on then "TealNeon" elseif spec.dim then "Iron" else "Copper")
			b.TextColor3 = rgb(if spec.on then "WalnutDark" else "Cream")
			local left = if spec.readyAt then spec.readyAt - now else 0
			b.Cooldown.Size = UDim2.fromScale(1, if left > 0 and spec.cooldown then math.clamp(left / spec.cooldown, 0, 1) else 0)
			setGlyph(b.Glyph, spec.glyph)
		end
	end
	-- lobby menu
	local lobby = phase == "Lobby" or (phase ~= "Day" and phase ~= "Night" and who == nil)
	for _, n in { "MenuShop", "MenuClass", "MenuSettings" } do
		el[n].Visible = lobby
	end
	el.SettingsMini.Visible = not lobby
	-- minimap + compass
	el.Minimap.Visible = inMatchPhase
	el.Compass.Visible = el.Minimap.Visible and who ~= nil
	if el.Minimap.Visible then
		Minimap.update(who, phase)
	end
	-- role card (first seconds of a round), item card, banner, ink, results
	modal.RoleCard.Visible = State.roleShownAt ~= nil and os.clock() - State.roleShownAt < 6 and phase == "Day"
	local card = State.itemCard
	modal.ItemCard.Visible = card ~= nil and os.clock() - card.at < 2.8
	local ban = State.banner
	modal.Banner.Visible = ban ~= nil and os.clock() - ban.at < (ban.seconds or 3.5) and not modal.RoleCard.Visible
	if ban then
		modal.Banner.Title.Text = ban.title
		modal.Banner.Title.TextColor3 = rgb(ban.color or "Brass")
		modal.Banner.Sub.Text = ban.sub or ""
	end
	modal.Ink.Visible = State.inkUntil ~= nil and os.clock() < State.inkUntil
	local res = State.results
	modal.Results.Visible = phase == "Results" and res ~= nil
	if res then
		modal.Results.Title.Text = string.upper(res.winner) .. " WIN"
		modal.Results.Title.TextColor3 = rgb(if res.winner == "Guests" then "TealNeon" else "MaskNeon")
		modal.Results.Reason.Text = res.reason
		local nights = {}
		for i, wnr in res.nights or {} do
			table.insert(nights, string.format("Night %d: %s", i, if wnr == "Guests" then "dawn ✔" else "dark ✘"))
		end
		modal.Results.Nights.Text = table.concat(nights, "   ")
		modal.Results.You.Text = (if res.won then "You won! " else "You lost. ") .. "+" .. tostring(res.tokens) .. " Gear Tokens" .. (if res.level then "   LEVEL UP! Lv " .. res.level else "")
		local names = {}
		for _, r in res.roster or {} do
			if r.role == "Phantom" then
				table.insert(names, r.name)
			end
		end
		modal.Results.Roster.Text = "The Phantoms were: " .. table.concat(names, ", ")
	end
end

-- Kid-friendly role card: a big title and 3 short lines with icons.
function Hud.showRole(role: string, mates: { string }?)
	State.roleShownAt = os.clock()
	local card = modal.RoleCard
	local me = Players.LocalPlayer
	if role == "Phantom" then
		card.Title.Text = "🎭 YOU ARE A PHANTOM!"
		card.Title.TextColor3 = rgb("MaskNeon")
		card.Line1.Text = "🤫  Day: act like a guest. Shh!"
		card.Line2.Text = "⚡  Stand at a breaker: TAMPER it"
		card.Line3.Text = "🌙  Night: TAG the guests!" .. (if mates and #mates > 0 then "  Team: " .. table.concat(mates, ", ") else "")
	else
		local cls = Gadgets.Classes[me and me:GetAttribute("PClass") or "Mechanist"] or Gadgets.Classes.Mechanist
		card.Title.Text = "🎩 YOU ARE A GUEST!"
		card.Title.TextColor3 = rgb("TealNeon")
		card.Line1.Text = "📦  Day: open chests, find items"
		card.Line2.Text = "🔧  Night: fix the RED breakers"
		card.Line3.Text = cls.icon .. "  " .. cls.name .. ": " .. cls.kid
	end
	for _, n in { "Line1", "Line2", "Line3" } do
		card[n].TextColor3 = rgb("Cream")
	end
end

function Hud.showItem(icon: string?, name: string, kid: string)
	State.itemCard = { at = os.clock() }
	modal.ItemCard.Icon.Text = icon or "✨"
	modal.ItemCard.ItemName.Text = name
	modal.ItemCard.Kid.Text = kid
end

function Hud.banner(title: string, sub: string?, color: string?, seconds: number?)
	State.banner = { title = title, sub = sub, color = color, seconds = seconds, at = os.clock() }
end

function Hud.slotItem(n: number): string?
	return slotItems[n]
end

function Hud.elements()
	return el, modal
end

return Hud
