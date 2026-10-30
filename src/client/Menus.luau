-- Modal panels, all fully navigable with a gamepad (GuiService.SelectedObject is set to the
-- first button when a panel opens; B closes it), touch and mouse:
--   Shop      tabs Masks / Lanterns / Trails / Emotes / Robux; buy with Gear Tokens, equip, and
--             (placeholder) Robux items that say "Coming soon" until their ids exist
--   Class     Mechanist / Illuminator cards
--   Settings  Music, Sound effects, Hints toggles + "Replay story intro" + "Replay tutorial"
--   Quests    daily + weekly objectives with live progress and Gear Token payouts, plus the
--             season track (tier, XP bar, premium flag, FREE + PREMIUM tier rewards); lobby
--             button + Settings
--   Vote      Expose vote at the Evidence Board: everyone in the match with their ribbon colour,
--             vote counts and the clues found today
--   Items     what each carried item does (icon, name, count, one-line tip)
--   Score     v1.6.1 mid-match scoreboard (Tab / L3, or Settings > Scoreboard on touch): name,
--             ribbon, In play / Wisp, chests; repairs only on the Results screen (role-safe,
--             see Logic/Score). Refreshes live while open.
--   Specials  v1.6.3 in-match Robux specials (Settings > Robux specials): cosmetic-only packs
--             flagged `inMatch`; every id is 0 until Murali creates the products, so each one
--             shows "Coming soon" and never opens a purchase prompt.
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
local QuestsCfg = require(Shared.Config.Quests)
local SeasonCfg = require(Shared.Config.Season)
local SeasonLogic = require(Shared.Logic.Season)
local Score = require(Shared.Logic.Score)
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
	-- v1.2: live-refresh the Quests panel (pcall: headless smoke players may lack the signal)
	pcall(function()
		Menus.watchQuests(Players.LocalPlayer)
	end)
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

-- v1.2: season window by the client clock (display only - the server decides XP and grants)
local function seasonLive(): boolean
	return SeasonLogic.active(SeasonCfg, math.floor(os.time() / 86400))
end

-- v1.2: Robux items the shop should not offer right now: the one-time starter trunk once
-- bought, and the season pass while no season is scheduled/running.
local function robuxHidden(key: string): boolean
	local def = Monetization.Products[key]
	if not def then
		return false
	end
	if def.starter and me():GetAttribute("StarterPackBought") == true then
		return true
	end
	if def.season and not seasonLive() then
		return true
	end
	return false
end
Menus.robuxHidden = robuxHidden

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
	elseif c.seasonTier then
		return (if c.seasonPremium then "👑 TIER " else "TIER ") .. c.seasonTier, if c.seasonPremium then "Velvet" else "Iron"
	elseif c.pass then
		return "VIP PASS", "Velvet"
	elseif c.product then
		return "R$ PACK", "Velvet"
	end
	return "?", "Iron"
end

local function promptRobux(kind: string, key: string)
	local def = if kind == "pass" then Monetization.Passes[key] else Monetization.Products[key]
	if kind == "product" and robuxHidden(key) then
		State.toast = { text = "You already have this one!", color = "Amber", at = os.clock() }
		return
	end
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
	elseif c.seasonTier then
		State.toast = {
			text = c.name .. ": reach season tier " .. c.seasonTier .. (if c.seasonPremium then " with the season pass!" else "!"),
			color = "Amber",
			at = os.clock(),
		}
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
			if robuxHidden(key) then
				continue
			end
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
	button("OpenQuests", "📜 Quests & Season", "Copper", g, function()
		Menus.open("Quests")
	end).LayoutOrder = 7
	-- v1.6.1 / v1.6.3: touch players reach the scoreboard and the in-match specials here
	button("OpenScore", "📊 Scoreboard", "Copper", g, function()
		Menus.open("Score")
	end).LayoutOrder = 8
	button("OpenSpecials", "💎 Robux specials", "Velvet", g, function()
		Menus.open("Specials")
	end).LayoutOrder = 9
end

-- v1.6.1 mid-match scoreboard (workspace attribute CM_Score, Logic/Score). Rows are
-- { rank, name, ribbon, state, counts } so the panel can lay them out in columns (a single
-- long text line shrinks to ~9 px on a portrait phone).
function Menus.scoreRows(): ({ any }, boolean)
	local phase = workspace:GetAttribute("CM_Phase") or "Lobby"
	local reveal = phase == "Results"
	local rows = {}
	for i, e in Score.decode(workspace:GetAttribute(Score.Attribute)) do
		local counts = string.format("📦 %d", e.chests)
		if reveal then
			counts ..= string.format("  🔧 %d", e.repairs)
		end
		table.insert(rows, { rank = i, name = e.name, ribbon = e.ribbon, state = e.state, counts = counts })
	end
	return rows, reveal
end

function builders.Score()
	local rows, reveal = Menus.scoreRows()
	title.Text = if reveal then "FINAL SCORES" else "SCOREBOARD"
	if #rows == 0 then
		local l = Hud.label("Empty", content, "No match running - the scoreboard opens when the doors do!")
		l.ZIndex = 12
		return
	end
	local g = grid(content, 1, 30)
	g.Size = UDim2.fromScale(1, 0.88)
	for i, row in rows do
		local f = Instance.new("Frame")
		f.Name = "Row" .. i
		f.LayoutOrder = i
		f.ZIndex = 12
		f.BorderSizePixel = 0
		f.BackgroundColor3 = rgb("TealDeep")
		f.BackgroundTransparency = if i % 2 == 0 then 1 else 0.75
		f.Parent = g
		local sw = Instance.new("Frame")
		sw.Name = "Ribbon"
		sw.ZIndex = 13
		sw.BorderSizePixel = 0
		sw.Size = UDim2.new(0, 8, 0.7, 0)
		sw.Position = UDim2.new(0, 4, 0.15, 0)
		local ok, c = pcall(rgb, row.ribbon)
		sw.BackgroundColor3 = if ok and typeof(c) == "Color3" then c else rgb("Cream")
		sw.Parent = f
		-- one fixed text size for every row (TextScaled per label made each row a different
		-- size); long names end in "..." instead of shrinking
		local cols = {
			{ "Name", string.format("%d. %s", row.rank, row.name), 0.04, 0.46, Enum.TextXAlignment.Left, "Cream" },
			{ "State", row.state, 0.5, 0.2, Enum.TextXAlignment.Center, if row.state == "Wisp" then "TealNeon" else "Cream" },
			{ "Counts", row.counts, 0.7, 0.3, Enum.TextXAlignment.Right, "Brass" },
		}
		for _, col in cols do
			local l = Hud.label(col[1], f, col[2])
			l.ZIndex = 13
			l.Position = UDim2.new(col[3], 6, 0.1, 0)
			l.Size = UDim2.new(col[4], -8, 0.8, 0)
			l.TextXAlignment = col[5]
			l.TextColor3 = rgb(col[6])
			l.TextScaled = false
			l.TextSize = 14
			l.TextTruncate = Enum.TextTruncate.AtEnd
		end
	end
	local hint = Hud.label("Hint", content, if reveal then "📦 chests found  ·  🔧 breakers fixed" else "📦 chests found  ·  repairs are revealed at the end")
	hint.ZIndex = 12
	hint.Size = UDim2.fromScale(1, 0.09)
	hint.Position = UDim2.fromScale(0, 0.91)
	hint.TextColor3 = rgb("TealNeon")
end

-- v1.6.3 in-match Robux specials: cosmetic only, "Coming soon" while the ids are 0
function builders.Specials()
	title.Text = "ROBUX SPECIALS"
	-- one column + wrapped text: product names run to 40+ characters, which TextScaled alone
	-- would shrink to ~6 px in a half-width cell on a portrait phone
	local g = grid(content, 1, 56)
	local n = 0
	for i, key in Monetization.inMatchProducts() do
		if robuxHidden(key) then
			continue
		end
		local def = Monetization.Products[key]
		n += 1
		local status = if def.id == 0 then "Coming soon" else "R$ " .. def.priceDraft
		local b = button("Special_" .. key, string.format("%s\n%s", def.name, status), "Velvet", g, function()
			promptRobux("product", key)
		end)
		b.LayoutOrder = i
		b.TextWrapped = true
	end
	if n == 0 then
		local l = Hud.label("Empty", content, "No specials right now")
		l.ZIndex = 12
	end
end

-- quest/season mirror (server -> player attributes, see DataService.publish):
--   QuestDaily / QuestWeekly = "id:progress/goal:done|..." (Logic/Quests.summary)
--   Season = "id:tier:premium" (id "" = no active season), SeasonXP = total season XP
local QuestDef = {}
for _, q in QuestsCfg.DailyPool do
	QuestDef[q.id] = q
end
for _, q in QuestsCfg.WeeklyPool do
	QuestDef[q.id] = q
end

local function questRows(attr: string): { any }
	local out = {}
	for _, part in string.split(me():GetAttribute(attr) or "", "|") do
		local id, prog, goal, done = string.match(part, "^(.-):(%d+)/(%d+):(%d)$")
		if id then
			table.insert(out, { id = id, progress = tonumber(prog) or 0, goal = tonumber(goal) or 1, done = done == "1" })
		end
	end
	return out
end

-- v1.3: two reward tracks - the free track everyone earns, and the premium track that needs the
-- season pass (Progression.owns gates on data.Season.Premium). Returns (freeLine, premiumLine).
local function seasonRewardLines(): (string, string)
	-- v1.4 review: sorted by tier NUMBER (a string sort put T10 before T3) and compact text so
	-- each track stays readable (>= ~15 px) on a 780x360 phone
	local free, prem = {}, {}
	for _, kind in { "Mask", "Lantern", "Trail", "Emote" } do
		for _, c in Cosmetics.ofKind(kind) do
			if c.seasonTier and (c.season == nil or c.season == SeasonCfg.Id) then
				table.insert(if c.seasonPremium then prem else free, c)
			end
		end
	end
	local function line(list): string
		table.sort(list, function(a, b)
			return a.seasonTier < b.seasonTier
		end)
		local bits = {}
		for _, c in list do
			local nm = string.gsub(c.name, "%s%(.*%)$", "")
			table.insert(bits, string.format("T%d %s%s", c.seasonTier, if c.icon then c.icon .. " " else "", nm))
		end
		return table.concat(bits, " · ")
	end
	return line(free), line(prem)
end

function builders.Quests()
	title.Text = string.format("QUESTS   ⚙ %d Gear Tokens", me():GetAttribute("GearTokens") or 0)
	-- season block (fixed at the top): state, XP bar, tier rewards (free + premium tracks)
	local season = Instance.new("Frame")
	season.Name = "Season"
	season.BackgroundTransparency = 1
	season.Size = UDim2.fromScale(1, 0.46)
	season.ZIndex = 12
	season.Parent = content
	local sname = Hud.label("SeasonName", season, "")
	sname.Size = UDim2.fromScale(1, 0.17)
	sname.TextXAlignment = Enum.TextXAlignment.Left
	sname.TextColor3 = rgb("Brass")
	local xpBar = Hud.panel("SeasonXP", "Iron", 0.2, season)
	xpBar.Size = UDim2.fromScale(1, 0.12)
	xpBar.Position = UDim2.fromScale(0, 0.19)
	local st = Instance.new("UIStroke")
	st.Color = rgb("Brass")
	st.Thickness = 1
	st.Parent = xpBar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = rgb("Gold")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = xpBar
	local xpText = Hud.label("Text", xpBar, "")
	xpText.ZIndex = 2
	xpText.TextStrokeTransparency = 0.5
	local rewards = Hud.label("Rewards", season, "")
	rewards.Size = UDim2.fromScale(1, 0.32)
	rewards.Position = UDim2.fromScale(0, 0.33)
	rewards.TextYAlignment = Enum.TextYAlignment.Top
	rewards.TextWrapped = true
	rewards.TextColor3 = rgb("Amber")
	local premRewards = Hud.label("PremiumRewards", season, "")
	premRewards.Size = UDim2.fromScale(1, 0.32)
	premRewards.Position = UDim2.fromScale(0, 0.67)
	premRewards.TextYAlignment = Enum.TextYAlignment.Top
	premRewards.TextWrapped = true
	premRewards.TextColor3 = rgb("Gold")
	local sid, tier, premium = string.match(me():GetAttribute("Season") or "", "^(.-):(%d+):(%d)$")
	if sid == nil or sid == "" or not seasonLive() then
		sname.Text = string.format("❄️ %s — COMING SOON!%s", SeasonCfg.Name, if premium == "1" then "  👑" else "")
		xpText.Text = "Season 1 starts when the gates open!"
		fill.Size = UDim2.fromScale(0, 1)
		premRewards.Text = "🔒 PASS TRACK: 5 extra winter cosmetics with the Winter Masquerade Pass (coming soon)"
	else
		local xp = me():GetAttribute("SeasonXP") or 0
		local t = math.min(tonumber(tier) or 1, SeasonCfg.TierCount)
		local crown = if premium == "1" then "  👑 PREMIUM" else ""
		sname.Text = string.format("❄️ %s — TIER %d/%d%s", SeasonCfg.Name, t, SeasonCfg.TierCount, crown)
		if t >= SeasonCfg.TierCount then
			fill.Size = UDim2.fromScale(1, 1)
			xpText.Text = "MAX TIER!"
		else
			local into = xp - (t - 1) * SeasonCfg.XpPerTier
			fill.Size = UDim2.fromScale(math.clamp(into / SeasonCfg.XpPerTier, 0, 1), 1)
			xpText.Text = string.format("%d / %d XP to tier %d", into, SeasonCfg.XpPerTier, t + 1)
		end
		local freeLine, premLine = seasonRewardLines()
		rewards.Text = "FREE: " .. freeLine
		premRewards.Text = (if premium == "1" then "👑 PASS: " else "🔒 PASS: ") .. premLine
	end
	-- quests (scroll): section headers + one row per quest
	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromScale(1, 0.52)
	area.Position = UDim2.fromScale(0, 0.48)
	area.ZIndex = 12
	area.Parent = content
	local g = grid(area, 1, 46)
	local order = 0
	local function section(text: string)
		order += 1
		local l = Hud.label("Section" .. order, g, text)
		l.LayoutOrder = order
		l.BackgroundTransparency = 0.4
		l.BackgroundColor3 = rgb("Coal")
		l.TextColor3 = rgb("Brass")
		l.ZIndex = 12
	end
	local function rows(attr: string)
		local list = questRows(attr)
		if #list == 0 then
			order += 1
			local l = Hud.label("Empty" .. order, g, "Finish a match to get your quests!")
			l.LayoutOrder = order
			l.ZIndex = 12
		end
		for _, q in list do
			order += 1
			local def = QuestDef[q.id]
			local text = if def then def.text else q.id
			local tokens = if def then def.tokens else 0
			local done = q.done or q.progress >= q.goal
			local b = button("Quest_" .. q.id, string.format("%s\n%d/%d   ⚙ %d%s", text, math.min(q.progress, q.goal), q.goal, tokens, if done then "  ✔" else ""), if done then "TealNeon" else "TealDeep", g, function()
			end)
			b.LayoutOrder = order
			b.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	section("📅 TODAY")
	rows("QuestDaily")
	section("🗓️ THIS WEEK")
	rows("QuestWeekly")
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

-- v1.2: live refresh of the Quests panel (quest progress, season XP/tier, tokens can change
-- while it is open - e.g. a payout lands). Rebuilds the panel and keeps the gamepad focus on the
-- same-named button.
local refreshQueued = false
local function refreshQuests()
	if State.panel ~= "Quests" or refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		if State.panel ~= "Quests" then
			return
		end
		local sel = GuiService.SelectedObject
		local selName = sel and sel:IsDescendantOf(frame) and sel.Name
		Menus.open("Quests")
		if selName and Input.device() == "gamepad" then
			local again = frame:FindFirstChild(selName, true)
			if again then
				pcall(function()
					GuiService.SelectedObject = again
				end)
			end
		end
	end)
end
Menus._refreshQuests = refreshQuests

-- v1.6.1: the scoreboard redraws when the standings change (at most once a second)
local scoreQueued = false
local function refreshScore()
	if State.panel ~= "Score" or scoreQueued then
		return
	end
	scoreQueued = true
	task.defer(function()
		scoreQueued = false
		if State.panel == "Score" then
			Menus.open("Score")
		end
	end)
end
Menus._refreshScore = refreshScore
pcall(function()
	workspace:GetAttributeChangedSignal(Score.Attribute):Connect(refreshScore)
end)

function Menus.watchQuests(player: Player)
	for _, a in { "QuestDaily", "QuestWeekly", "Season", "SeasonXP", "GearTokens" } do
		player:GetAttributeChangedSignal(a):Connect(refreshQuests)
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
