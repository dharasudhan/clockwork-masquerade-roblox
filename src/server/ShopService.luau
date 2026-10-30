-- Shop + cosmetics + Robux monetization (COSMETIC ONLY, no pay-to-win).
--   * Gear Token purchases (Action "buy"), equipping (Action "equip"), emotes (Action "emote").
--   * Cosmetics on characters: everyone's masquerade mask, the match ribbon colour (Expose
--     clues), lantern skin + beam colour, Electro-Wisp trail colour.
--   * Robux: game passes (VIP / Sterling Founder / 2x Gear Tokens / Masquerade Host) checked on
--     join and when a purchase finishes; developer products granted ONLY in ProcessReceipt,
--     idempotent through the save's receipt log (PurchaseId), with the profile saved before
--     PurchaseGranted. v1.1 adds: starter pack flag, token chest, season pass premium flag.
--     v1.3 adds: the season pass instantly grants + auto-equips its exclusive mask
--     (prod.instantCosmetic). All product ids are placeholders (0) until Gate 4/5: a 0 id is
--     never prompted.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)
local Match = require(Shared.Config.Match)
local Progression = require(Shared.Logic.Progression)
local Billboard = require(Shared.Billboard)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local DataService = require(script.Parent.DataService)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local ShopService = {}

ShopService.EmoteCooldown = 4
local emoteAt: { [any]: number } = {}

-- ---- equip / buy -----------------------------------------------------------------------------
function ShopService.buy(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" then
		return false, "bad id"
	end
	local data = DataService.get(player)
	if not data then
		return false, "no save"
	end
	local c = Cosmetics.byId(id)
	local ok, why = Progression.canBuy(c, data)
	if not ok then
		return false, why
	end
	data.GearTokens -= c.tokens
	data.Owned[c.id] = true
	DataService.publish(player)
	Net.send(player, { kind = "bought", id = c.id, name = c.name })
	Net.sfx(player, "Tokens")
	return true
end

function ShopService.equip(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" then
		return false, "bad id"
	end
	local data = DataService.get(player)
	local c = Cosmetics.byId(id)
	if not data or not c then
		return false, "unknown"
	end
	if not Progression.owns(c, data, DataService.passes(player)) then
		return false, "locked"
	end
	data.Equipped[c.kind] = c.id
	DataService.publish(player)
	local p = Participants.ofPlayer(player)
	if p then
		ShopService.dress(p)
	elseif player.Character then
		ShopService.dressModel(player.Character, player, nil)
	end
	return true
end

-- the cosmetic of `kind` p shows (bots: a random free/level one, players: their equipped one)
local function equipped(p, kind: string)
	if p.player then
		local data = DataService.get(p.player)
		local id = data and data.Equipped[kind] or Cosmetics.Defaults[kind]
		return Cosmetics.byId(id) or Cosmetics.byId(Cosmetics.Defaults[kind])
	end
	p.botLook = p.botLook or {}
	if not p.botLook[kind] then
		local pool = {}
		for _, c in Cosmetics.ofKind(kind) do
			if c.free or c.level then
				table.insert(pool, c)
			end
		end
		p.botLook[kind] = pool[math.random(1, #pool)]
	end
	return p.botLook[kind]
end
ShopService.equipped = equipped

local function torso(m: Model): BasePart?
	return (m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")) :: BasePart?
end

-- Masquerade mask + ribbon on a character model.
function ShopService.dressModel(m: Model, player: Player?, p: any?)
	local head = m:FindFirstChild("Head") :: BasePart?
	if head then
		local old = m:FindFirstChild("MasqueradeMask")
		if old then
			old:Destroy()
		end
		local mask = if p then equipped(p, "Mask") else (function()
			local data = player and DataService.get(player)
			return Cosmetics.byId(data and data.Equipped.Mask or Cosmetics.Defaults.Mask)
		end)()
		if mask then
			local part = Build.part({ name = "MasqueradeMask", parent = m, size = Vector3.new(1.15, 0.42, 0.18), cf = head.CFrame * CFrame.new(0, 0.18, -0.58), color = mask.color, material = Enum.Material.Metal, anchored = false, collide = false, massless = true, query = false })
			Build.weld(head, part)
			for _, s in { -1, 1 } do
				local eye = Build.part({ name = "MaskEye", parent = part, size = Vector3.new(0.3, 0.16, 0.05), cf = part.CFrame * CFrame.new(s * 0.25, 0.02, -0.1), color = "Coal", material = Enum.Material.SmoothPlastic, anchored = false, collide = false, massless = true, query = false })
				Build.weld(part, eye)
			end
			part:SetAttribute("Cosmetic", mask.id)
			if m:FindFirstChild("PhantomMask") then
				part.Transparency = 1
			end
		end
	end
	if p and p.ribbon then
		local t = torso(m)
		local old = m:FindFirstChild("Ribbon")
		if old then
			old:Destroy()
		end
		if t then
			local r = Build.part({ name = "Ribbon", parent = m, size = Vector3.new(0.35, 2.3, 0.12), cf = t.CFrame * CFrame.new(0, 0, -t.Size.Z / 2 - 0.07) * CFrame.Angles(0, 0, math.rad(35)), color = p.ribbon, material = Enum.Material.Neon, anchored = false, collide = false, massless = true, query = false })
			Build.weld(t, r)
			if m:FindFirstChild("PhantomMask") then
				r.Transparency = 1 -- v1.4: the night Phantom stays anonymous after a re-dress
			end
		end
	end
end

-- Everything cosmetic for a participant (start of round, respawn, after equip).
function ShopService.dress(p)
	if p.model then
		ShopService.dressModel(p.model, p.player, p)
	end
	local lantern = equipped(p, "Lantern")
	p.lanternSkin = lantern and { color = lantern.color, beam = lantern.beam } or nil
	local trail = equipped(p, "Trail")
	p.trailColor = trail and trail.color or "Wisp"
end

-- ---- emotes ------------------------------------------------------------------------------
function ShopService.emote(player: Player?, p: any, id: any): boolean
	local model = (p and p.model) or (player and player.Character)
	if not model then
		return false
	end
	local key = player or p
	local now = Clock.now()
	if emoteAt[key] and now - emoteAt[key] < ShopService.EmoteCooldown then
		return false
	end
	local c = if type(id) == "string" then Cosmetics.byId(id) else nil
	if not c or c.kind ~= "Emote" then
		return false
	end
	if player then
		local data = DataService.get(player)
		if not data or not Progression.owns(c, data, DataService.passes(player)) then
			return false
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	emoteAt[key] = now
	local gui = Billboard.new("Emote", "EmoteBubble")
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.Parent = head
	local t = Instance.new("TextLabel")
	t.Name = "Icon"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = c.icon or "✨"
	t.Parent = gui
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "EmoteBurst"
	pe.Color = ColorSequence.new(Build.color(c.color))
	pe.LightEmission = 0.8
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(4, 8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.35, 0)
	pe.Parent = head
	pcall(function()
		pe:Emit(30)
	end)
	task.delay(2.5, function()
		gui:Destroy()
		pe:Destroy()
	end)
	return true
end

-- ---- Robux: passes + products ------------------------------------------------------------
local function grantPass(player: Player, key: string)
	DataService.passes(player)[key] = true
	DataService.publish(player)
	local p = Participants.ofPlayer(player)
	if p then
		ShopService.dress(p)
	end
end
ShopService.grantPass = grantPass

function ShopService.tokenMultiplier(player: Player?): number
	if player and DataService.passes(player).DoubleTokens then
		return Monetization.Passes.DoubleTokens.tokenMultiplier
	end
	return 1
end

local function checkPasses(player: Player)
	for key, pass in Monetization.Passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
end

-- ProcessReceipt (idempotent). Exposed for tests.
-- v1.1: `prod.starter` marks the one-time starter pack; `prod.season` unlocks the season's
-- premium track (SeasonWinter -> data.Season.Premium; tier cosmetics unlock via Progression).
-- v1.3: `prod.instantCosmetic` grants + auto-equips its exclusive mask the moment the pass is
-- bought, before any tier is earned.
function ShopService.processReceipt(info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local pid = tostring(info.PurchaseId)
	if data.Purchases[pid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (retry)
	end
	local key, prod = Monetization.productById(info.ProductId)
	if not prod then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- unknown product: keep it open
	end
	for _, id in prod.grants or {} do
		data.Owned[id] = true
	end
	if prod.tokens then
		data.GearTokens += prod.tokens
	end
	if prod.starter then
		data.StarterPackBought = true
	end
	if prod.season then
		if data.Season.Id ~= prod.season then
			-- v1.4 review fix: a save still carrying an older season's track starts this season's
			-- track now; otherwise QuestService.seasonXp would see the old id at the next match
			-- end and wipe the premium flag that was just paid for.
			data.Season.Id = prod.season
			data.Season.XP = 0
			data.Season.Tier = 1
		end
		data.Season.Premium = true
		-- v1.3: instant gratification - the pass immediately grants + equips its exclusive mask.
		-- v1.4 review fix: the gift goes into Owned (kept for good, like any bought cosmetic), and
		-- premium rewards for tiers already reached unlock at once.
		local gift = Cosmetics.byId(prod.instantCosmetic or "")
		if gift then
			data.Owned[gift.id] = true
			data.Equipped[gift.kind] = gift.id
		end
		for _, id in Progression.seasonRewards(Cosmetics.Items, data.Season.Id, data.Season.Tier or 1, true) do
			data.Owned[id] = true
		end
	end
	local now = Clock.wall()
	data.Purchases[pid] = now
	-- keep the log small: Roblox stops retrying a receipt after a few days
	for k, t in data.Purchases do
		if type(t) == "number" and now - t > 14 * 86400 then
			data.Purchases[k] = nil
		end
	end
	DataService.publish(player)
	if prod.season then
		-- wear the new mask right away (in-match participant, else the lobby character)
		local p = Participants.ofPlayer(player)
		if p then
			ShopService.dress(p)
		elseif player.Character then
			ShopService.dressModel(player.Character, player, nil)
		end
	end
	Net.send(player, { kind = "bought", id = key, name = prod.name, robux = true })
	Net.sfx(player, "Tokens")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.init()
	DataService.onLoaded(checkPasses)
	pcall(function()
		MarketplaceService.ProcessReceipt = ShopService.processReceipt
	end)
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if purchased then
				local key = Monetization.passById(passId)
				if key then
					grantPass(player, key)
				end
			end
		end)
	end)
end

-- random distinct ribbon colours for this match
function ShopService.assignRibbons(list)
	local pool = table.clone(Match.Ribbons)
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i, p in list do
		p.ribbon = pool[((i - 1) % #pool) + 1]
		Participants.set(p, "Ribbon", p.ribbon)
	end
end

return ShopService
