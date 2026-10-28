-- Phone-first HUD: role chip, phase timer pill (top centre), objective line, reboot meter,
-- toasts, carried items, lantern battery, up to 3 context buttons (left of the touch jump
-- button), the role reveal card and the results card. Rects come from Logic/HudLayout.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared.Logic.HudLayout)
local Nights = require(Shared.Config.Nights)
local Gadgets = require(Shared.Config.Gadgets)
local Style = require(Shared.Config.Style)
local State = require(script.Parent.State)

local Hud = {}

local function rgb(name: string): Color3
	local c = Style.Palette[name] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

local gui: ScreenGui = nil :: any
local el: { [string]: any } = {}
local modal: { [string]: any } = {}
local buttonActions: { string? } = {}
local onButton: ((string) -> ())? = nil
local lastLayoutKey = ""

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

local function panel(name: string, color: string, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = rgb(color)
	f.BackgroundTransparency = transparency or 0.15
	f.BorderSizePixel = 0
	f.Parent = gui
	corner(f, 8)
	return f
end

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
	el.Inventory = panel("Inventory", "WalnutDark", 0.3)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = el.Inventory
	for i, item in { "DryCell", "CopperWire", "GlowStick" } do
		local l = label(item, el.Inventory)
		l.Size = UDim2.fromScale(1 / 3, 1)
		l.LayoutOrder = i
	end
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
		b.Activated:Connect(function()
			local a = buttonActions[i]
			if a and onButton then
				onButton(a)
			end
		end)
		el["Button" .. i] = b
	end
	-- modal cards
	modal.RoleCard = panel("RoleCard", "WalnutDark", 0.05)
	stroke(modal.RoleCard, rgb("Brass"), 3)
	local t = label("Title", modal.RoleCard)
	t.Size = UDim2.fromScale(1, 0.5)
	t.Font = Enum.Font.Sarpanch
	local s = label("Sub", modal.RoleCard)
	s.Size = UDim2.new(0.9, 0, 0.4, 0)
	s.Position = UDim2.fromScale(0.05, 0.52)
	s.Font = Enum.Font.Gotham
	modal.RoleCard.Visible = false
	modal.Results = panel("Results", "WalnutDark", 0.05)
	stroke(modal.Results, rgb("Brass"), 3)
	local rt = label("Title", modal.Results)
	rt.Size = UDim2.fromScale(1, 0.28)
	rt.Font = Enum.Font.Sarpanch
	local rr = label("Reason", modal.Results)
	rr.Size = UDim2.fromScale(0.9, 0.16)
	rr.Position = UDim2.fromScale(0.05, 0.28)
	local ry = label("You", modal.Results)
	ry.Size = UDim2.fromScale(0.9, 0.18)
	ry.Position = UDim2.fromScale(0.05, 0.46)
	local rl = label("Roster", modal.Results)
	rl.Size = UDim2.fromScale(0.9, 0.3)
	rl.Position = UDim2.fromScale(0.05, 0.66)
	rl.Font = Enum.Font.Gotham
	modal.Results.Visible = false
	return gui
end

function Hud.onButton(cb: (string) -> ())
	onButton = cb
end

function Hud.gui(): ScreenGui
	return gui
end

-- Positions every element for a w x h GUI area.
function Hud.applyLayout(w: number, h: number, touch: boolean)
	local L = HudLayout.compute(w, h, touch)
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
		o.Position = UDim2.fromOffset(math.floor(r.x), math.floor(r.y))
		o.Size = UDim2.fromOffset(math.floor(r.w), math.floor(r.h))
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

local PhaseName = { Lobby = "LOBBY", Day = "DAY", Night = "NIGHT", Results = "RESULTS" }

-- Context buttons: { action, text, readyAt?, on? }
function Hud.buttonsFor(phase: string, who: string?, attrs): { any }
	local out = {}
	if phase ~= "Night" or who == nil then
		return out
	end
	if who == "Guest" then
		table.insert(out, { action = "lantern", text = if attrs.LanternOn then "LAMP ON" else "LAMP", on = attrs.LanternOn == true })
		table.insert(out, { action = "cell", text = "CELL " .. (attrs.DryCell or 0), dim = (attrs.DryCell or 0) <= 0 })
		table.insert(out, { action = "glow", text = "GLOW " .. (attrs.GlowStick or 0), dim = (attrs.GlowStick or 0) <= 0 })
	elseif who == "Phantom" then
		table.insert(out, { action = "tag", text = "TAG", readyAt = attrs.TagReadyAt, cooldown = Gadgets.Phantom.tagCooldown })
	elseif who == "Wisp" then
		table.insert(out, { action = "flicker", text = "FLICKER", readyAt = attrs.FlickerReadyAt, cooldown = Gadgets.Wisp.flickerCooldown })
		table.insert(out, { action = "slick", text = "SLICK", readyAt = attrs.SlickReadyAt, cooldown = Gadgets.Wisp.slickCooldown })
	end
	return out
end

function Hud.objective(phase: string, who: string?): string
	if phase == "Lobby" then
		return "The masquerade begins soon - bots fill up to 6 guests"
	elseif phase == "Results" then
		return "Back to the terrace in a moment..."
	end
	if who == nil then
		return "Masquerade in progress - you join the next one"
	end
	local n = Nights[workspace:GetAttribute("CM_Night") or 1] or Nights[1]
	local byPhase = n.objective[phase] or {}
	return byPhase[who] or byPhase.Guest or ""
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
	local key = string.format("%dx%d%s", w, h, tostring(touch))
	if key ~= lastLayoutKey then
		lastLayoutKey = key
		Hud.applyLayout(w, h, touch)
	end
	local phase = State.phase()
	local who = State.who()
	local now = workspace:GetServerTimeNow()
	local me = Players.LocalPlayer
	local attrs = if me then me:GetAttributes() else {}
	-- timer pill
	el.Timer.Text.Text = (PhaseName[phase] or phase) .. "  " .. fmt(State.timeLeft())
	-- objective (a channel in progress overrides it)
	local obj = Hud.objective(phase, who)
	local ch = State.channel
	if ch and ch.channel == "Tamper" and ch.seconds then
		obj = string.format("Tampering... stand still (%.1f s)", math.max(0, ch.seconds - (now - ch.startedAt)))
	elseif attrs.Repairing then
		obj = "Repairing breaker " .. tostring(attrs.Repairing) .. "... stand still"
	elseif attrs.Slowed then
		obj = "Oil slick! You're slowed"
	end
	el.Objective.Text.Text = obj
	-- reboot meter (night)
	local reboot = workspace:GetAttribute("CM_Reboot") or 0
	el.Reboot.Visible = phase == "Night"
	el.Reboot.Fill.Size = UDim2.fromScale(math.clamp(reboot / 100, 0, 1), 1)
	el.Reboot.Text.Text = string.format("GRID REBOOT %d%%", math.floor(reboot))
	-- role chip
	local chipText, chipColor = "TERRACE", "TealDeep"
	if who == "Guest" then
		chipText, chipColor = "GUEST", "TealDeep"
	elseif who == "Phantom" then
		chipText, chipColor = if phase == "Day" then "PHANTOM (secret)" else "PHANTOM", "Velvet"
	elseif who == "Wisp" or who == "Bubble" then
		chipText, chipColor = "ELECTRO-WISP", "Iron"
	elseif phase ~= "Lobby" then
		chipText = "SPECTATING"
	end
	el.RoleChip.Text.Text = chipText
	el.RoleChip.BackgroundColor3 = rgb(chipColor)
	-- items + battery
	local showItems = who == "Guest" or (who == "Phantom" and phase == "Day")
	el.Inventory.Visible = showItems
	el.Inventory.DryCell.Text = "CELL " .. (attrs.DryCell or 0)
	el.Inventory.CopperWire.Text = "WIRE " .. (attrs.CopperWire or 0)
	el.Inventory.GlowStick.Text = "GLOW " .. (attrs.GlowStick or 0)
	local battery = attrs.Battery or 0
	el.Battery.Visible = showItems
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
	local btns = Hud.buttonsFor(phase, who, attrs)
	for i = 1, 3 do
		local b = el["Button" .. i]
		local spec = btns[i]
		buttonActions[i] = spec and spec.action
		b.Visible = spec ~= nil
		if spec then
			b.Text = spec.text
			b.BackgroundColor3 = rgb(if spec.on then "TealNeon" elseif spec.dim then "Iron" else "Copper")
			b.TextColor3 = rgb(if spec.on then "WalnutDark" else "Cream")
			local left = if spec.readyAt then spec.readyAt - now else 0
			b.Cooldown.Size = UDim2.fromScale(1, if left > 0 and spec.cooldown then math.clamp(left / spec.cooldown, 0, 1) else 0)
		end
	end
	-- role card (first seconds of a round) and results card
	modal.RoleCard.Visible = State.roleShownAt ~= nil and os.clock() - State.roleShownAt < 4.5 and phase == "Day"
	local res = State.results
	modal.Results.Visible = phase == "Results" and res ~= nil
	if res then
		modal.Results.Title.Text = string.upper(res.winner) .. " WIN"
		modal.Results.Title.TextColor3 = rgb(if res.winner == "Guests" then "TealNeon" else "MaskNeon")
		modal.Results.Reason.Text = res.reason
		modal.Results.You.Text = (if res.won then "You won! " else "You lost. ") .. "+" .. tostring(res.tokens) .. " Gear Tokens"
		local names = {}
		for _, r in res.roster or {} do
			if r.role == "Phantom" then
				table.insert(names, r.name)
			end
		end
		modal.Results.Roster.Text = "The Phantoms were: " .. table.concat(names, ", ")
	end
end

function Hud.showRole(role: string, mates: { string }?)
	State.roleShownAt = os.clock()
	local card = modal.RoleCard
	if role == "Phantom" then
		card.Title.Text = "YOU ARE A PHANTOM"
		card.Title.TextColor3 = rgb("MaskNeon")
		local m = if mates and #mates > 0 then " Fellow Phantom: " .. table.concat(mates, ", ") .. "." else ""
		card.Sub.Text = "Blend in by day and tamper with a breaker. At night, unmask and tag every guest." .. m
	else
		card.Title.Text = "YOU ARE A GUEST"
		card.Title.TextColor3 = rgb("TealNeon")
		card.Sub.Text = "Scavenge chests by day. At night repair the grid and shine your lantern at the Phantoms."
	end
end

function Hud.elements()
	return el, modal
end

return Hud
