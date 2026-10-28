-- Day scavenging: stocks Night.chestCount brass-bound chests at random Config/Manor spots,
-- each opened once (ProximityPrompt hold, server checks range + phase). Loot goes into the
-- opener's carried items (caps in Config/Gadgets). Phantoms may open chests too: they keep
-- decoy loot they cannot use, so item counters never give their role away.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Gadgets = require(Shared.Config.Gadgets)
local Loot = require(Shared.Logic.Loot)
local Billboard = require(Shared.Billboard)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local ManorBuilder = require(script.Parent.ManorBuilder)
local Net = require(script.Parent.Net)

local ChestService = {}

local chests: { [string]: any } = {}
local rng = Random.new()
local night: any = nil
local openHook: ((any, string) -> ())? = nil

local ItemNames = { DryCell = "Dry-cell", CopperWire = "Copper wire", GlowStick = "Glow-stick" }

function ChestService.onOpened(cb)
	openHook = cb
end

local function chestModel(id: string, x: number, z: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = id
	local body = Build.part({ name = "Body", parent = m, size = Vector3.new(3.2, 2, 2.2), pos = Vector3.new(x, 1, z), color = "Walnut", material = Enum.Material.Wood })
	Build.part({ name = "Lid", parent = m, size = Vector3.new(3.3, 0.6, 2.3), pos = Vector3.new(x, 2.3, z), color = "WalnutDark", material = Enum.Material.Wood })
	for _, dx in { -1.1, 1.1 } do
		Build.part({ name = "Band", parent = m, size = Vector3.new(0.3, 2.7, 2.35), pos = Vector3.new(x + dx, 1.35, z), color = "Brass", material = Enum.Material.Metal, collide = false })
	end
	local glow = Build.part({ name = "Latch", parent = m, size = Vector3.new(0.6, 0.6, 0.2), pos = Vector3.new(x, 1.8, z - 1.2), color = "TealNeon", material = Enum.Material.Neon, collide = false })
	Build.light(glow, "PointLight", Build.color("TealNeon"), 0.6, 7)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Search"
	prompt.ActionText = "Search"
	prompt.ObjectText = "Chest"
	prompt.HoldDuration = night.chestOpenSeconds
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ForRole", "Any")
	prompt:SetAttribute("ForPhase", "Day")
	prompt.Parent = body
	m.PrimaryPart = body
	m:SetAttribute("ChestId", id)
	m.Parent = parent
	return m, prompt
end

function ChestService.stock(nightCfg)
	ChestService.clear()
	night = nightCfg
	local b = ManorBuilder.get()
	local folder = b.manor:FindFirstChild("Chests")
	local picks = Loot.pickSpots(#Manor.ChestSpots, nightCfg.chestCount, function()
		return rng:NextNumber()
	end)
	for n, idx in picks do
		local spot = Manor.ChestSpots[idx]
		local id = "Chest_" .. n
		local model, prompt = chestModel(id, spot.x, spot.z, folder)
		chests[id] = { id = id, x = spot.x, z = spot.z, model = model, opened = false }
		prompt.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p then
				ChestService.open(p, id)
			end
		end)
	end
end

function ChestService.clear()
	for _, c in chests do
		if c.model then
			c.model:Destroy()
		end
	end
	table.clear(chests)
end

function ChestService.unopened()
	local out = {}
	for _, c in chests do
		if not c.opened then
			table.insert(out, c)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- Server-validated open. Returns the item id (or "full") on success, nil when refused.
function ChestService.open(p, id: string): string?
	local c = chests[id]
	if c == nil or c.opened or p.state == "Bubble" or p.state == "Wisp" then
		return nil
	end
	if workspace:GetAttribute("CM_Phase") ~= "Day" then
		return nil
	end
	local pos = Participants.pos(p)
	if pos == nil or (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(c.x, 0, c.z)).Magnitude > 9 then
		return nil
	end
	c.opened = true
	local item = Loot.roll(night.loot, rng:NextNumber())
	local added = Loot.add(p.inv, item, Gadgets.Inventory.caps)
	p.stats.chests += 1
	Participants.set(p, item, p.inv[item])
	if p.player then
		Net.toast(p.player, if added then "+1 " .. ItemNames[item] else ItemNames[item] .. " - you can't carry more", "TealNeon")
		Net.sfx(p.player, "Chest")
	end
	-- opened chests sink their lid glow
	local latch = c.model:FindFirstChild("Latch")
	if latch then
		latch.Color = Build.color("Iron")
		local l = latch:FindFirstChildOfClass("PointLight")
		if l then
			l.Enabled = false
		end
	end
	local prompt = c.model:FindFirstChild("Body") and c.model.Body:FindFirstChild("Search")
	if prompt then
		prompt:SetAttribute("Done", true) -- clients hide it (PromptFilter owns Enabled locally)
		prompt.Enabled = false
	end
	if openHook then
		openHook(p, item)
	end
	return if added then item else "full"
end

ChestService.ItemNames = ItemNames
return ChestService
