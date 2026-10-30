-- v1.4.1 night shroud. At nightfall every Phantom (human or bot) loses everything that identifies
-- its avatar - clothing, accessories/hair/layered clothing, face decal, body colours and skin
-- textures, the bot fallback hat, the lantern skin, its own trails - and wears one uniform
-- steampunk cloak instead: hood, mantle, long tattered skirt, sleeves, brass clasp and glowing
-- clockwork eyes. At dawn / match end it is undone exactly (Logic/Shroud ledger); a respawn
-- during the night re-applies it on the new character (the old stash is dropped with the old
-- character). By day a Phantom looks like any guest, as before.
--
-- Safe by construction: shroud parts are unanchored, massless, CanCollide/CanQuery/CanTouch off
-- and welded to the body, so hitboxes (root-based), raycasts, the lantern, held items and the
-- Phase Glide / Shockwave Dash VFX (in workspace.Effects) are unaffected. Parts sit inside the
-- character model, so they stream in and out with it under StreamingEnabled. 15 primitives per
-- Phantom, no assets.
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Shroud = require(Shared.Logic.Shroud)
local Build = require(script.Parent.Build)

local ShroudService = {}

-- id -> { model = Model, ledger = ledger, folder = Folder }
local active: { [number]: any } = {}
local serial = 0

local function stashRoot(): Instance
	return ServerStorage:FindFirstChild("CM_ShroudStash") or Build.folder("CM_ShroudStash", ServerStorage)
end

local function idOf(m: Model): number?
	local id = m:GetAttribute(Shroud.Attr)
	return if type(id) == "number" then id else nil
end

function ShroudService.isOn(m: Model?): boolean
	return m ~= nil and idOf(m :: Model) ~= nil and (m :: Model):FindFirstChild(Shroud.ModelName) ~= nil
end

local function vec(t): Vector3
	return Vector3.new(t[1], t[2], t[3])
end
local function arr(v3: Vector3)
	return { v3.X, v3.Y, v3.Z }
end

-- rig measurements for Logic/Shroud.layout
local function measure(m: Model)
	local head = m:FindFirstChild("Head") :: BasePart?
	local torso = (m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")) :: BasePart?
	if not head or not torso then
		return nil
	end
	local r6 = m:FindFirstChild("UpperTorso") == nil
	local lowest = math.huge
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and Shroud.BodyParts[c.Name] then
			lowest = math.min(lowest, c.CFrame.Position.Y - c.Size.Y / 2)
		end
	end
	local drop = torso.CFrame.Position.Y - lowest
	if drop < torso.Size.Y / 2 + 0.5 then
		-- legless / partial rig (tests, odd avatars): use the humanoid hip height
		local h = m:FindFirstChildOfClass("Humanoid")
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hip = if h then h.HipHeight else 2
		drop = if root then (torso.CFrame.Position.Y - root.CFrame.Position.Y) + root.Size.Y / 2 + math.max(hip, 2) else torso.Size.Y / 2 + 2
	end
	local la = (m:FindFirstChild("LeftUpperArm") or m:FindFirstChild("Left Arm")) :: BasePart?
	local ra = (m:FindFirstChild("RightUpperArm") or m:FindFirstChild("Right Arm")) :: BasePart?
	return {
		dims = { head = arr(head.Size), torso = arr(torso.Size), drop = drop, arm = if la and ra then arr(la.Size) else nil, r6 = r6 },
		anchors = { head = head, torso = torso, leftArm = la, rightArm = ra },
	}
end

local SHAPES = { Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder, Block = Enum.PartType.Block }
local MATERIALS = { Fabric = Enum.Material.Fabric, Neon = Enum.Material.Neon, Metal = Enum.Material.Metal }

local function buildCloak(m: Model, info): Model
	local cloak = Instance.new("Model")
	cloak.Name = Shroud.ModelName
	for _, sp in Shroud.layout(info.dims) do
		local anchor = info.anchors[sp.anchor] :: BasePart?
		if anchor then
			local cf = anchor.CFrame * CFrame.new(vec(sp.pos)) * CFrame.Angles(math.rad(sp.rot[1]), math.rad(sp.rot[2]), math.rad(sp.rot[3]))
			local part: BasePart
			if sp.shape == "Wedge" then
				local w = Instance.new("WedgePart")
				w.Name = sp.name
				w.Size = vec(sp.size)
				w.CFrame = cf
				w.Color = Build.color(sp.color)
				w.Material = MATERIALS[sp.material]
				w.Anchored = false
				w.CanCollide = false
				w.CanQuery = false
				w.CanTouch = false
				w.CastShadow = false
				w.Massless = true
				w.Parent = cloak
				part = w
			else
				part = Build.part({ name = sp.name, parent = cloak, shape = SHAPES[sp.shape], size = vec(sp.size), cf = cf, color = sp.color, material = MATERIALS[sp.material], anchored = false, collide = false, query = false, touch = false, shadow = sp.material == "Fabric", massless = true })
			end
			Build.weld(anchor, part)
			if sp.name == "EyeL" then
				Build.light(part, "PointLight", Build.color(Shroud.Eye), 1.4, 7)
			end
		end
	end
	cloak.Parent = m
	return cloak
end

-- Put the shroud on a character (idempotent: a second call only re-checks / tops up).
function ShroudService.apply(m: Model?): boolean
	if m == nil or m.Parent == nil then
		return false
	end
	local model = m :: Model
	local id = idOf(model)
	local rec = id and active[id]
	if not rec then
		serial += 1
		id = serial
		local folder = Instance.new("Folder")
		folder.Name = tostring(id)
		folder.Parent = stashRoot()
		rec = { model = model, ledger = Shroud.newLedger(), folder = folder }
		active[id :: number] = rec
		model:SetAttribute(Shroud.Attr, id)
	end
	local ledger, folder = rec.ledger, rec.folder
	local shroudColor, lampColor = Build.color(Shroud.Color), Build.color(Shroud.LampColor)
	-- collect first (re-parenting while iterating descendants is unsafe)
	local todo = {}
	local function walk(parent: Instance, inside: boolean)
		for _, c in parent:GetChildren() do
			local action = Shroud.classify(c.ClassName, c.Name, c:IsA("BasePart"), inside)
			if action ~= "keep" then
				table.insert(todo, { inst = c, action = action })
			end
			if not c:IsA("Humanoid") then
				walk(c, inside or action == "keep" and parent == model or action == "stash")
			end
		end
	end
	walk(model, false)
	for _, job in todo do
		local c, action = job.inst, job.action
		if action == "stash" then
			Shroud.rememberParent(ledger, c, c.Parent)
			c.Parent = folder
		elseif action == "hide" then
			Shroud.rememberProp(ledger, c, "Transparency", (c :: any).Transparency)
			;(c :: any).Transparency = 1
		elseif action == "disable" then
			Shroud.rememberProp(ledger, c, "Enabled", (c :: any).Enabled)
			;(c :: any).Enabled = false
		elseif action == "lamp" then
			Shroud.rememberProp(ledger, c, "Color", (c :: BasePart).Color)
			;(c :: BasePart).Color = lampColor
		elseif action == "body" then
			Shroud.rememberProp(ledger, c, "Color", (c :: BasePart).Color)
			;(c :: BasePart).Color = shroudColor
			if c:IsA("MeshPart") then
				Shroud.rememberProp(ledger, c, "TextureID", (c :: MeshPart).TextureID)
				pcall(function()
					(c :: MeshPart).TextureID = ""
				end)
			end
		end
	end
	if not model:FindFirstChild(Shroud.ModelName) then
		local info = measure(model)
		if info then
			buildCloak(model, info)
		end
	end
	return true
end

local function dropRecord(id: number)
	local rec = active[id]
	if rec then
		if rec.folder then
			rec.folder:Destroy()
		end
		active[id] = nil
	end
end

-- Take the shroud off and restore the avatar exactly.
function ShroudService.remove(m: Model?): boolean
	if m == nil then
		return false
	end
	local model = m :: Model
	local id = idOf(model)
	local cloak = model:FindFirstChild(Shroud.ModelName)
	if cloak then
		cloak:Destroy()
	end
	model:SetAttribute(Shroud.Attr, nil)
	local rec = id and active[id]
	if not rec then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	for _, e in Shroud.undo(rec.ledger) do
		local target = e.target
		if e.kind == "parent" then
			if e.old ~= nil and (e.old == model or e.old:IsDescendantOf(model)) then
				-- the engine drops an accessory's AccessoryWeld when it leaves the character, so an
				-- accessory goes back through Humanoid:AddAccessory (re-welds, re-wraps layered
				-- clothing); anything else (or no humanoid) is simply parented back
				local done = false
				if humanoid and target:IsA("Accessory") then
					done = pcall(function()
						target.Parent = nil
						humanoid:AddAccessory(target)
					end) and target.Parent == model
				end
				if not done then
					target.Parent = e.old
				end
			end
		elseif target.Parent ~= nil then
			pcall(function()
				target[e.prop] = e.old
			end)
		end
	end
	dropRecord(id :: number)
	return true
end

-- Forget stashes whose character is gone (respawned / left). The new character comes with the
-- avatar's own clothes, so nothing needs restoring there.
function ShroudService.prune(): number
	local n = 0
	for id, rec in active do
		if rec.model.Parent == nil then
			dropRecord(id)
			n += 1
		end
	end
	return n
end

-- Match end: everyone back to normal, every stash dropped.
function ShroudService.clearAll()
	local ids = {}
	for id in active do
		table.insert(ids, id)
	end
	for _, id in ids do
		local rec = active[id]
		if rec and rec.model.Parent ~= nil then
			ShroudService.remove(rec.model)
		else
			dropRecord(id)
		end
	end
end

function ShroudService.count(): number
	local n = 0
	for _ in active do
		n += 1
	end
	return n
end

return ShroudService
