-- Modal panels, all fully navigable with a gamepad (GuiService.SelectedObject is set to the
-- first button when a panel opens; B closes it), touch and mouse:
--   Shop      tabs Masks / Lanterns / Trails / Emotes / Robux; buy with Gear Tokens, equip, and
--             (placeholder) Robux items that say "Coming soon" until their ids exist
--   Class     Mechanist / Illuminator cards
--   Settings  Music, Sound effects, Hints toggles + "Replay story intro" + "Replay tutorial"
--   Vote      Expose vote at the Evidence Board: everyone in the match with their ribbon colour,
--             vote counts and the clues found today
--   Items     what each carried item does (icon, name, count, one-line tip)
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)
local Gadgets = require(Shared.Config.Gadgets)
local Items = require(Shared.Config.Items)
local Match = require(Shared.Config.Match)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)

local Menus = {}

local rgb = Hud.rgb
local frame: Frame = nil :: any
local content: Frame = nil :: any
local title: TextLabel = nil :: any
local send: ((string, any?) -> ())? = nil
local onReplay: ((string) -> ())? = nil
local shopTab = "Mask"
local firstButton: GuiObject? = nil

function Menus.init(sendFn: (string, any?) -> (), replayFn: (string) -> ())
	send = sendFn
	onReplay = replayFn
	local gui = Hud.gui()
	frame = Hud.panel("Panel", "WalnutDark", 0.04, gui)
	frame.Visible = false
	frame.ZIndex = 10
	local s = Instance.new("UIStroke")
	s.Color = rgb("Brass")
	s.Thickness = 3
	s.Parent = frame
	title = Hud.label("Title", frame, "")
	title.Size = UDim2.fromScale(0.7, 0.12)
	title.Position = UDim2.fromScale(0.03, 0.02)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Sarpanch
	title.TextColor3 = rgb("Brass")
	title.ZIndex = 11
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromScale(0.16, 0.11)
	close.Position = UDim2.fromScale(0.82, 0.02)
	close.BackgroundColor3 = rgb("Crimson")
	close.TextColor3 = rgb("Cream")
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	close.Text = "CLOSE"
	close.ZIndex = 11
	close.Selectable = true
	close.Parent = frame
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	close.Activated:Connect(function()
		Menus.close()
	end)
	content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(0.94, 0.82)
	content.Position = UDim2.fromScale(0.03, 0.15)
	content.ZIndex = 11
	content.Parent = frame
end

local function clear()
	for _, c in content:GetChildren() do
		c:Destroy()
	end
	firstButton = nil
end

local function button(name: string, text: string, color: string, parent: Instance, cb: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = rgb(color)
	b.TextColor3 = rgb("Cream")
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	b.Selectable = true
	b.AutoButtonColor = true
	b.ZIndex = 12
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = rgb("Brass")
	st.Thickness = 1
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = b
	b.Activated:Connect(cb)
	if firstButton == nil then
		firstButton = b
	end
	return b
end
Menus.button = button

local function grid(parent: Instance, cols: number, rowsH: number): Frame
	local f = Instance.new("ScrollingFrame")
	f.Name = "Grid"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ScrollBarThickness = 6
	f.AutomaticCanvasSize = Enum.AutomaticSize.Y
	f.CanvasSize = UDim2.fromScale(0, 0)
	f.Selectable = false
	f.ZIndex = 12
	f.Parent = parent
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(1 / cols, -6, 0, rowsH)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return f :: any
end

local function me(): Player
	return Players.LocalPlayer
end

local function owned(id: string): boolean
	local list = me():GetAttribute("Owned") or ""
	return table.find(string.split(list, ","), id) ~= nil
end

local function cosmeticStatus(c): (string, string)
	local equipped = me():GetAttribute("Equip_" .. c.kind) == c.id
	if equipped then
		return "EQUIPPED", "TealNeon"
	elseif owned(c.id) then
		return "EQUIP", "TealDeep"
	elseif c.tokens then
		return "⚙ " .. c.tokens, "Copper"
	elseif c.level then
		return "LEVEL " .. c.level, "Iron"
	elseif c.daily then
		return "DAY " .. c.daily .. " GIFT", "Iron"
	elseif c.pass then
		return "VIP PASS", "Velvet"
	elseif c.product then
		return "R$ PACK", "Velvet"
	end
	return "?", "Iron"
end

local function promptRobux(kind: string, key: string)
	local def = if kind == "pass" then Monetization.Passes[key] else Monetization.Products[key]
	if not def or def.id == 0 then
		State.toast = { text = "Coming soon! (Robux items are not on sale yet)", color = "Amber", at = os.clock() }
		return
	end
	pcall(function()
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(me(), def.id)
		else
			MarketplaceService:PromptProductPurchase(me(), def.id)
		end
	end)
end

local function clickCosmetic(c)
	if owned(c.id) then
		if send then
			send("equip", c.id)
		end
	elseif c.tokens then
		if send then
			send("buy", c.id)
		end
	elseif c.level then
		State.toast = { text = c.name .. " unlocks at level " .. c.level .. "!", color = "Amber", at = os.clock() }
	elseif c.daily then
		State.toast = { text = c.name .. ": log in " .. c.daily .. " days in a row!", color = "Amber", at = os.clock() }
	elseif c.pass then
		promptRobux("pass", c.pass)
	elseif c.product then
		promptRobux("product", c.product)
	end
	task.delay(0.4, function()
		if State.panel == "Shop" then
			Menus.open("Shop")
		end
	end)
end

local TabNames = { Mask = "MASKS", Lantern = "LANTERNS", Trail = "TRAILS", Emote = "EMOTES", Robux = "ROBUX" }

local builders = {}

function builders.Shop()
	title.Text = string.format("SHOP   ⚙ %d Gear Tokens", me():GetAttribute("GearTokens") or 0)
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.fromScale(1, 0.14)
	tabs.ZIndex = 12
	tabs.Parent = content
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	for i, k in { "Mask", "Lantern", "Trail", "Emote", "Robux" } do
		local b = button("Tab_" .. k, TabNames[k], if shopTab == k then "TealNeon" else "TealDeep", tabs, function()
			shopTab = k
			Menus.open("Shop")
		end)
		b.LayoutOrder = i
		b.Size = UDim2.new(0.2, -5, 1, 0)
	end
	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromScale(1, 0.84)
	area.Position = UDim2.fromScale(0, 0.16)
	area.ZIndex = 12
	area.Parent = content
	local g = grid(area, 3, 52)
	if shopTab == "Robux" then
		for i, key in Monetization.ShopOrder do
			local isPass = Monetization.Passes[key] ~= nil
			local def = if isPass then Monetization.Passes[key] else Monetization.Products[key]
			local status = if def.id == 0 then "(soon)" else ""
			local b = button("Robux_" .. key, string.format("%s\nR$ %d %s", def.name, def.priceDraft, status), "Velvet", g, function()
				promptRobux(if isPass then "pass" else "product", key)
			end)
			b.LayoutOrder = i
		end
	else
		for i, c in Cosmetics.ofKind(shopTab) do
			local status, color = cosmeticStatus(c)
			local b = button("Item_" .. c.id, (c.icon and c.icon .. " " or "") .. c.name .. "\n" .. status, color, g, function()
				clickCosmetic(c)
			end)
			b.LayoutOrder = i
		end
	end
end

function builders.Class()
	title.Text = "CHOOSE YOUR CLASS"
	local g = grid(content, 2, 150)
	for i, k in Gadgets.ClassOrder do
		local c = Gadgets.Classes[k]
		local sel = me():GetAttribute("Class") == k
		local b = button("Class_" .. k, string.format("%s %s%s\n%s\nGadget: %s", c.icon, c.name, if sel then "  ✔" else "", c.kid, c.gadgetName), if sel then "TealNeon" else "TealDeep", g, function()
			if send then
				send("class", k)
			end
			task.delay(0.4, function()
				if State.panel == "Class" then
					Menus.open("Class")
				end
			end)
		end)
		b.LayoutOrder = i
	end
end

function builders.Settings()
	title.Text = "SETTINGS"
	local g = grid(content, 2, 48)
	local function toggle(key: string, name: string)
		local on = me():GetAttribute("Set_" .. key) ~= false
		return button("Toggle_" .. key, name .. ": " .. (if on then "ON" else "OFF"), if on then "TealDeep" else "Iron", g, function()
			if send then
				send("setting", { key = key, value = not on })
			end
			me():SetAttribute("Set_" .. key, not on) -- instant local feedback; the server confirms
			Menus.open("Settings")
		end)
	end
	toggle("Music", "🎵 Music").LayoutOrder = 1
	toggle("Sfx", "🔊 Sound effects").LayoutOrder = 2
	toggle("Hints", "💡 Hints").LayoutOrder = 3
	button("ReplayIntro", "🎬 Replay story intro", "Copper", g, function()
		Menus.close()
		if onReplay then
			onReplay("intro")
		end
	end).LayoutOrder = 4
	button("ReplayTutorial", "🧭 Replay tutorial", "Copper", g, function()
		Menus.close()
		if onReplay then
			onReplay("tutorial")
		end
	end).LayoutOrder = 5
	button("OpenShop", "🛒 Shop", "Copper", g, function()
		Menus.open("Shop")
	end).LayoutOrder = 6
end

-- everyone in the match (players' characters + bots) that can still be voted for
function Menus.candidates(): { any }
	local out = {}
	local function consider(m: Instance?)
		if m and m:GetAttribute("InMatch") and m:GetAttribute("PId") then
			local ps = m:GetAttribute("PState")
			if ps == "Guest" or ps == "Phantom" then
				table.insert(out, { id = m:GetAttribute("PId"), name = m:GetAttribute("PName") or m.Name, ribbon = m:GetAttribute("Ribbon") })
			end
		end
	end
	for _, pl in Players:GetPlayers() do
		consider(pl.Character)
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, b in (if bots then bots:GetChildren() else {}) do
		consider(b)
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

function builders.Vote()
	title.Text = "WHO IS A PHANTOM? VOTE!"
	local clues = workspace:GetAttribute("CM_Clues") or ""
	local info = Hud.label("Clues", content, if clues == "" then "No clues yet - inspect breakers for glitter!" else "Clues: " .. string.gsub(clues, ",", "   "))
	info.Size = UDim2.fromScale(1, 0.12)
	info.TextColor3 = rgb("Amber")
	info.ZIndex = 12
	local counts = {}
	for _, part in string.split(workspace:GetAttribute("CM_Votes") or "", ",") do
		local kv = string.split(part, "=")
		if #kv == 2 then
			counts[kv[1]] = tonumber(kv[2])
		end
	end
	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromScale(1, 0.86)
	area.Position = UDim2.fromScale(0, 0.14)
	area.ZIndex = 12
	area.Parent = content
	local g = grid(area, 2, 44)
	local mine = me():GetAttribute("VotedFor")
	local myId = me():GetAttribute("PId")
	for i, c in Menus.candidates() do
		if c.id ~= myId then
			local colour = Match.RibbonNames[c.ribbon or ""] or "?"
			local b = button("Vote_" .. c.id, string.format("%s  (%s ribbon)  %s", c.name, colour, if counts[c.id] then "🗳️" .. counts[c.id] else ""), if mine == c.id then "TealNeon" else "TealDeep", g, function()
				if send then
					send("vote", c.id)
				end
				task.delay(0.4, function()
					if State.panel == "Vote" then
						Menus.open("Vote")
					end
				end)
			end)
			b.LayoutOrder = i
			local chip = Instance.new("Frame")
			chip.Name = "RibbonChip"
			chip.Size = UDim2.fromScale(0.05, 0.8)
			chip.Position = UDim2.fromScale(-0.03, 0.1)
			chip.BackgroundColor3 = rgb(c.ribbon or "Cream")
			chip.BorderSizePixel = 0
			chip.ZIndex = 13
			chip.Parent = b
		end
	end
end

function builders.Items()
	title.Text = "YOUR ITEMS"
	local g = grid(content, 1, 46)
	local any = false
	for i, id in Items.Order do
		local n = me():GetAttribute(id) or 0
		if n > 0 then
			any = true
			local def = Items.Defs[id]
			local b = button("Info_" .. id, string.format("%s  %s x%d  -  %s", def.icon or "", def.name, n, def.tip or def.hint), "TealDeep", g, function()
				State.selected = if def.use then id else State.selected
				State.picked = id
				Menus.close()
			end)
			b.LayoutOrder = i
			b.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	if not any then
		local l = Hud.label("Empty", content, "No items yet - open chests by day! 📦")
		l.ZIndex = 12
	end
end

local function bindClose(on: boolean)
	if on then
		ContextActionService:BindActionAtPriority("CM_closePanel", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Menus.close()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, 3000, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	else
		ContextActionService:UnbindAction("CM_closePanel")
	end
end

function Menus.open(kind: string)
	if not frame or not builders[kind] then
		return
	end
	clear()
	builders[kind]()
	frame.Visible = true
	if State.panel == nil then
		bindClose(true)
	end
	State.panel = kind
	local r = Hud.layout() and Hud.layout().modal.Panel
	if r then
		frame.Position = UDim2.fromOffset(math.floor(r.x), math.floor(r.y))
		frame.Size = UDim2.fromOffset(math.floor(r.w), math.floor(r.h))
	end
	if firstButton == nil then
		firstButton = frame:FindFirstChild("Close") :: GuiObject?
	end
	if Input.device() == "gamepad" and firstButton then
		pcall(function()
			GuiService.SelectedObject = firstButton
		end)
	end
end

function Menus.toggle(kind: string)
	if State.panel == kind then
		Menus.close()
	else
		Menus.open(kind)
	end
end

function Menus.close()
	if not frame then
		return
	end
	frame.Visible = false
	if State.panel then
		bindClose(false)
	end
	State.panel = nil
	pcall(function()
		GuiService.SelectedObject = nil
	end)
end

function Menus.frame(): Frame
	return frame
end

function Menus.firstButton(): GuiObject?
	return firstButton
end

return Menus
