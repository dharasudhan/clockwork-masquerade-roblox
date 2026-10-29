-- Night 2 "Blueprint Archives" (GDD): by Day, 3 blueprint pages hide in 3 of the manor's 8
-- cabinets (Library, Drafting Loft, Map Room, Study, Wine Cellar, Trophy Room, Attic Storeroom,
-- Tower Lookout). Anyone who looks like a guest can search a cabinet (hold 1.5 s). Phantoms can
-- trap up to 2 cabinets per Day: the next searcher gets ink on their screen for 3 s and an alarm
-- tells everyone the room. By Night, guests carrying pages slot them into the projector in the
-- Library: each page widens a light barrier around it that pushes Phantoms out for the rest of
-- the night, and jumps the reboot meter (+6% per page, +8% more for all three).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Loot = require(Shared.Logic.Loot)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Participants = require(script.Parent.Participants)
local ManorBuilder = require(script.Parent.ManorBuilder)
local GridService = require(script.Parent.GridService)
local Build = require(script.Parent.Build)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local ArchiveService = {}

local cfg: any = nil -- night.archives (nil on nights without archives)
local cabinets: { [string]: any } = {} -- id -> { page, trapped, searched }
local slotted = 0
local trapsLeft = 0
local rng = Random.new()
local promptsReady = false
local hooks = { slotted = nil :: any }

function ArchiveService.onSlotted(cb)
	hooks.slotted = cb
end

function ArchiveService.active(): boolean
	return cfg ~= nil
end

local function setPrompts()
	local built = ManorBuilder.get()
	if not built then
		return
	end
	for id, h in built.props.cabinets do
		local c = cabinets[id]
		local search = h.prompt:FindFirstChild("Search")
		local trap = h.prompt:FindFirstChild("Trap")
		if search then
			search:SetAttribute("Done", cfg == nil or c == nil or c.searched)
		end
		if trap then
			trap:SetAttribute("Done", cfg == nil or c == nil or c.searched or c.trapped or trapsLeft <= 0)
		end
	end
	local slot = built.props.projector.prompt:FindFirstChild("Slot")
	if slot then
		slot:SetAttribute("Done", cfg == nil or slotted >= cfg.pages)
		slot:SetAttribute("NeedsAttr", "Pages")
	end
end

local function ensurePrompts()
	if promptsReady then
		return
	end
	local built = ManorBuilder.get()
	if not built then
		return
	end
	promptsReady = true
	for id, h in built.props.cabinets do
		local search = Instance.new("ProximityPrompt")
		search.Name = "Search"
		search.ActionText = "Search for pages"
		search.ObjectText = "Blueprint cabinet"
		search.HoldDuration = 1.5
		search.MaxActivationDistance = 8
		search.RequiresLineOfSight = false
		search:SetAttribute("ForRole", "Any")
		search:SetAttribute("ForPhase", "Day")
		search:SetAttribute("ForNight", 2)
		search.Parent = h.prompt
		search.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p then
				ArchiveService.search(p, id)
			end
		end)
		local trap = Instance.new("ProximityPrompt")
		trap.Name = "Trap"
		trap.ActionText = "Trap cabinet (ink + alarm)"
		trap.ObjectText = "Blueprint cabinet"
		trap.HoldDuration = 2
		trap.MaxActivationDistance = 8
		trap.RequiresLineOfSight = false
		trap.UIOffset = Vector2.new(0, 60)
		trap.KeyboardKeyCode = Enum.KeyCode.T
		trap:SetAttribute("ForRole", "Phantom")
		trap:SetAttribute("ForPhase", "Day")
		trap:SetAttribute("ForNight", 2)
		trap.Parent = h.prompt
		trap.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p then
				ArchiveService.trap(p, id)
			end
		end)
	end
	local slot = Instance.new("ProximityPrompt")
	slot.Name = "Slot"
	slot.ActionText = "Slot blueprint page"
	slot.ObjectText = "Projector"
	slot.HoldDuration = 1
	slot.MaxActivationDistance = 9
	slot.RequiresLineOfSight = false
	slot:SetAttribute("ForRole", "Guest")
	slot:SetAttribute("ForPhase", "Night")
	slot:SetAttribute("ForNight", 2)
	slot.Parent = built.props.projector.prompt
	slot.Triggered:Connect(function(player)
		local p = Participants.ofPlayer(player)
		if p then
			ArchiveService.slot(p)
		end
	end)
end

local function barrierRadius(): number
	if not cfg or slotted <= 0 then
		return 0
	end
	return cfg.barrierBase + cfg.barrierPerPage * (slotted - 1)
end
ArchiveService.barrierRadius = barrierRadius

local function visuals()
	local built = ManorBuilder.get()
	if not built then
		return
	end
	local pr = built.props.projector
	local r = barrierRadius()
	local on = r > 0 and workspace:GetAttribute("CM_Phase") == "Night"
	pr.zone.Transparency = if on then 0.75 else 1
	pr.zone.Size = if on then Vector3.new(r * 2, 10, r * 2) else Vector3.new(1, 1, 1)
	pr.light.Brightness = if on then 4 else 0
	workspace:SetAttribute("CM_Pages", slotted)
	workspace:SetAttribute("CM_PagesNeed", if cfg then cfg.pages else 0)
	workspace:SetAttribute("CM_Barrier", r)
end

function ArchiveService.reset(night)
	ensurePrompts()
	cfg = night.archives
	slotted = 0
	table.clear(cabinets)
	for _, p in Participants.all() do
		p.pages = 0
		Participants.set(p, "Pages", nil)
	end
	if cfg then
		local ids = {}
		for _, c in Manor.Cabinets do
			table.insert(ids, c.id)
			cabinets[c.id] = { page = false, trapped = false, searched = false }
		end
		local picks = Loot.pickSpots(#ids, cfg.pages, function()
			return rng:NextNumber()
		end)
		for _, i in picks do
			cabinets[ids[i]].page = true
		end
		trapsLeft = cfg.traps
	else
		trapsLeft = 0
	end
	workspace:SetAttribute("CM_TrapsLeft", trapsLeft)
	setPrompts()
	visuals()
end

local function near(p, x: number, y: number, z: number, range: number): boolean
	local pos = Participants.pos(p)
	return pos ~= nil and math.abs(pos.Y - (y + 3)) < 7 and Vector3.new(pos.X - x, 0, pos.Z - z).Magnitude <= range
end

function ArchiveService.search(p, id: string): string?
	if not cfg or workspace:GetAttribute("CM_Phase") ~= "Day" or p.state ~= "Guest" then
		return nil
	end
	local c = cabinets[id]
	local h = ManorBuilder.get().props.cabinets[id]
	if not c or not h or c.searched or not near(p, h.x, h.y, h.z, 9) then
		return nil
	end
	c.searched = true
	p.stats.chests += 1
	local result = "empty"
	if c.trapped then
		result = "trap"
		local room = ManorLayout.ids(Manor)[h.room]
		if p.player then
			Net.send(p.player, { kind = "ink", seconds = cfg.inkSeconds })
		end
		Net.toast("all", "ALARM! A trapped cabinet went off in the " .. room.name .. "!", "BreakerBad")
		Net.sfx("all", "Alarm")
		workspace:SetAttribute("CM_BellAt", string.format("%.1f,%.1f,%.1f", h.x, h.y + 3, h.z))
		workspace:SetAttribute("CM_BellTime", Clock.now())
	end
	if c.page then
		result = if result == "trap" then "trap+page" else "page"
		p.pages = (p.pages or 0) + 1
		Participants.set(p, "Pages", p.pages)
		if p.player then
			Net.send(p.player, { kind = "item", item = "BlueprintPage", icon = "📜", name = "Blueprint page", kid = "Take it to the Projector at night!" })
			Net.sfx(p.player, "Pickup")
		end
		Net.toast("all", p.name .. " found a blueprint page!", "TealNeon")
	elseif result == "empty" and p.player then
		Net.toast(p.player, "No pages in this cabinet.", "Cream")
	end
	setPrompts()
	return result
end

function ArchiveService.trap(p, id: string): boolean
	if not cfg or workspace:GetAttribute("CM_Phase") ~= "Day" or p.role ~= "Phantom" or trapsLeft <= 0 then
		return false
	end
	local c = cabinets[id]
	local h = ManorBuilder.get().props.cabinets[id]
	if not c or not h or c.searched or c.trapped or not near(p, h.x, h.y, h.z, 9) then
		return false
	end
	c.trapped = true
	trapsLeft -= 1
	workspace:SetAttribute("CM_TrapsLeft", trapsLeft)
	if p.player then
		Net.toast(p.player, "Cabinet trapped! The next searcher gets inked.", "MaskNeon")
	end
	setPrompts()
	return true
end

function ArchiveService.slot(p): boolean
	if not cfg or workspace:GetAttribute("CM_Phase") ~= "Night" or p.role ~= "Guest" or p.state ~= "Guest" then
		return false
	end
	if (p.pages or 0) <= 0 or slotted >= cfg.pages then
		return false
	end
	local pr = ManorBuilder.get().props.projector
	if not near(p, pr.x, pr.y, pr.z, 10) then
		return false
	end
	local n = p.pages
	p.pages = 0
	Participants.set(p, "Pages", nil)
	local before = slotted
	slotted = math.min(cfg.pages, slotted + n)
	local added = slotted - before
	p.stats.pages = (p.stats.pages or 0) + added
	local grid = GridService.state()
	if grid then
		local bonus = cfg.rebootPerPage * added + (if slotted >= cfg.pages and before < cfg.pages then cfg.rebootAllPages else 0)
		grid.reboot = math.min(100, grid.reboot + bonus)
		workspace:SetAttribute("CM_Reboot", grid.reboot)
	end
	Net.toast("all", string.format("Page %d/%d in the projector! Light barrier: %d studs", slotted, cfg.pages, barrierRadius()), "TealNeon")
	Net.sfx("all", "Key")
	if hooks.slotted then
		hooks.slotted(p, added)
	end
	visuals()
	setPrompts()
	return true
end

-- the barrier (Night): { x, y, z, radius } or nil
function ArchiveService.barrier()
	local r = barrierRadius()
	if r <= 0 or workspace:GetAttribute("CM_Phase") ~= "Night" then
		return nil
	end
	local pr = ManorBuilder.get().props.projector
	return { x = pr.x, y = pr.y, z = pr.z, radius = r }
end

function ArchiveService.step(_dt: number)
	if not cfg then
		return
	end
	-- pages held by tagged guests (or unmasked Phantoms) are lost at night
	if workspace:GetAttribute("CM_Phase") == "Night" then
		for _, p in Participants.all() do
			if (p.pages or 0) > 0 and p.state ~= "Guest" then
				p.pages = 0
				Participants.set(p, "Pages", nil)
			end
		end
	end
	visuals()
end

function ArchiveService.state()
	return { cabinets = cabinets, slotted = slotted, trapsLeft = trapsLeft, cfg = cfg }
end

-- unsearched cabinets as bot/compass targets
function ArchiveService.openCabinets()
	local out = {}
	local built = ManorBuilder.get()
	if not cfg or not built then
		return out
	end
	for id, c in cabinets do
		if not c.searched then
			local h = built.props.cabinets[id]
			table.insert(out, { id = id, x = h.x, y = h.y, z = h.z, trapped = c.trapped })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function ArchiveService.clear()
	cfg = nil
	slotted = 0
	table.clear(cabinets)
	setPrompts()
	visuals()
end

return ArchiveService
