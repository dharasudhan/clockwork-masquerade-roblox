-- v1.4.1 night shroud (pure, unit-tested): what a night Phantom's avatar must lose, the uniform
-- cloak every Phantom (human or bot) wears instead, and the undo ledger that makes it reversible.
--
-- Why a stash ledger and not Humanoid:ApplyDescription: ApplyDescription(Async) yields, loads
-- assets over the network and can fail (Nevermore's HumanoidDescriptionUtils wraps it in a
-- pcall/Promise for that reason), it does not cover our own cosmetic parts (masquerade mask,
-- ribbon, lantern skin, the bot fallback hat) and it cannot run in the headless smoke. The stash
-- is synchronous: identifying instances are re-parented to a server-only folder and changed
-- properties are written to a ledger, and undo replays the ledger backwards. No new assets.
local Shroud = {}

Shroud.ModelName = "PhantomShroud" -- the cloak Model welded onto the character
Shroud.Attr = "CM_Shrouded" -- model attribute while the shroud is on
Shroud.Color = "Shroud" -- palette keys (Config/Style)
Shroud.Edge = "ShroudEdge"
Shroud.Eye = "ClockEye"
Shroud.Clasp = "Brass"
Shroud.LampColor = "Brass" -- every night Phantom's lantern looks the default one

-- Children that identify the wearer and are removed (re-parented to the stash) while shrouded.
local STASH_CLASSES = {
	Accessory = true, -- hats, hair, faces, layered clothing (WrapLayer lives inside these)
	Accoutrement = true,
	Hat = true,
	Shirt = true,
	Pants = true,
	ShirtGraphic = true,
	BodyColors = true,
	CharacterMesh = true, -- R6 bundle meshes
	SurfaceAppearance = true, -- PBR skin on body parts
	WrapLayer = true, -- layered clothing parented straight onto a part (rare)
}
-- Our own/round parts that must never be touched by the stash.
local KEEP_NAMES = {
	HumanoidRootPart = true,
	PhantomMask = true,
	PhantomGlow = true,
	PhantomShroud = true,
	HeldItem = true,
	WispOrb = true,
	WispRing = true,
	MasqueradeMask = true, -- already hidden by the Phantom transform (ChaseService.maskOn)
	Ribbon = true, -- already hidden by setNameShown (v1.4)
}
-- Named cosmetic parts that identify a model and are hidden (Transparency 1).
local HIDE_PART_NAMES = {
	Hat = true, -- the bot fallback rig's top hat
	HatBrim = true,
}

-- Body parts (R15 + R6) that get the shroud colour. Anything else that is a part and not named
-- here belongs to some other system (held item, key, emote prop) and is left alone.
local BODY = {}
for _, n in { "Head", "UpperTorso", "LowerTorso", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
	BODY[n] = true
end
for _, side in { "Left", "Right" } do
	for _, n in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
		BODY[side .. n] = true
	end
end
Shroud.BodyParts = BODY

-- What to do with one instance found on a character.
--   "keep"    leave alone
--   "stash"   re-parent to the stash folder
--   "hide"    Transparency -> 1 (decals, textures, named cosmetic parts)
--   "body"    body part: Color -> shroud colour, MeshPart TextureID -> ""
--   "lamp"    lantern lamp: Color -> the default brass (skins identify their owner)
--   "disable" Enabled -> false (an avatar's own trails / sparkles)
-- inside: the instance sits inside something we already stash or keep (skip it).
function Shroud.classify(className: string, name: string, isPart: boolean, inside: boolean?): string
	if inside or KEEP_NAMES[name] then
		return "keep"
	end
	if STASH_CLASSES[className] then
		return "stash"
	end
	if className == "Decal" or className == "Texture" then
		return "hide"
	end
	if className == "Trail" or className == "Sparkles" or className == "Fire" or className == "Smoke" then
		return "disable"
	end
	if isPart then
		if name == "LanternLamp" then
			return "lamp"
		end
		if HIDE_PART_NAMES[name] then
			return "hide"
		end
		if BODY[name] then
			return "body"
		end
	end
	return "keep"
end

-- ---- undo ledger -------------------------------------------------------------------------
-- A ledger is a list of entries { target, kind = "parent" | "prop", prop, old }. remember()
-- keeps only the FIRST value per (target, prop), so applying twice never records the shroud's
-- own colour as the "original". undo() returns the entries newest-first and empties the ledger.
-- `same(a, b)` compares targets (Instances compare with ==; tests use tables).
function Shroud.newLedger()
	return { entries = {} }
end

local function find(ledger, target, kind: string, prop: string?): boolean
	for _, e in ledger.entries do
		if e.target == target and e.kind == kind and e.prop == prop then
			return true
		end
	end
	return false
end

function Shroud.rememberProp(ledger, target, prop: string, old: any): boolean
	if find(ledger, target, "prop", prop) then
		return false
	end
	table.insert(ledger.entries, { target = target, kind = "prop", prop = prop, old = old })
	return true
end

function Shroud.rememberParent(ledger, target, oldParent: any): boolean
	if find(ledger, target, "parent", nil) then
		return false
	end
	table.insert(ledger.entries, { target = target, kind = "parent", old = oldParent })
	return true
end

function Shroud.size(ledger): number
	return #ledger.entries
end

function Shroud.undo(ledger)
	local out = {}
	for i = #ledger.entries, 1, -1 do
		table.insert(out, ledger.entries[i])
	end
	table.clear(ledger.entries)
	return out
end

-- ---- uniform cloak geometry -----------------------------------------------------------------
-- dims: { head = {x,y,z}, torso = {x,y,z}, drop = studs from the torso centre to the floor,
--         arm = {x,y,z}? (upper arm on R15, whole arm on R6), r6 = bool }
-- Returns part specs relative to their anchor ("head" | "torso" | "leftArm" | "rightArm"):
-- { name, anchor, shape = "Block"|"Ball"|"Cylinder"|"Wedge", size = {x,y,z}, pos = {x,y,z},
--   rot = {rx,ry,rz} degrees, color = palette key, material = "Fabric"|"Neon"|"Metal" }.
-- Colours, materials, names and the part count never depend on the avatar, so every Phantom
-- reads the same; only the fit scales with the rig (R15, R6, rthro).
Shroud.EyeZ = -0.82 -- in front of the Phantom mask (ChaseService.maskOn: z -0.62, 0.3 thick)

local function v(x, y, z)
	return { x, y, z }
end

function Shroud.layout(d)
	local h, t = d.head, d.torso
	local hy = math.max(h[2], 0.8)
	local s = math.max(t[2] / (if d.r6 then 2 else 1.6), 0.5) -- body scale vs a default rig
	local out = {}
	local function add(name, anchor, shape, size, pos, rot, color, material)
		table.insert(out, { name = name, anchor = anchor, shape = shape, size = size, pos = pos, rot = rot or v(0, 0, 0), color = color, material = material })
	end
	-- hood: a ball around the head, pushed back so the face sits inside it, plus a swept peak
	local dia = hy * 1.5
	add("Hood", "head", "Ball", v(dia, dia, dia), v(0, hy * 0.08, dia * 0.1), nil, Shroud.Color, "Fabric")
	add("HoodPeak", "head", "Wedge", v(dia * 0.5, dia * 0.35, dia * 0.45), v(0, dia * 0.5, dia * 0.2), nil, Shroud.Color, "Fabric")
	-- glowing clockwork eyes (gear discs facing forward), in front of hood and mask
	local eyeZ = math.min(Shroud.EyeZ, -(dia * 0.4) - 0.06)
	local eye = 0.26 * math.max(hy / 1.2, 0.8)
	for i, sx in { -1, 1 } do
		add(if i == 1 then "EyeL" else "EyeR", "head", "Cylinder", v(0.08, eye, eye), v(sx * 0.24 * math.max(hy / 1.2, 0.8), hy * 0.15, eyeZ), v(0, 90, 0), Shroud.Eye, "Neon")
	end
	-- mantle over shoulders and chest, brass gear clasp at the collar
	add("Mantle", "torso", "Block", v(t[1] * 1.3, t[2] * 1.02, t[3] * 1.5), v(0, t[2] * 0.06, 0), nil, Shroud.Color, "Fabric")
	add("Clasp", "torso", "Cylinder", v(0.12, 0.45 * s, 0.45 * s), v(0, t[2] * 0.4, -(t[3] * 0.75 + 0.06)), v(0, 90, 0), Shroud.Clasp, "Metal")
	-- long skirt from the waist to just above the floor (legs move inside it)
	local top = t[2] * 0.4
	local bottom = math.max(d.drop - 0.25, top + 0.5)
	local hgt = bottom - top
	add("Skirt", "torso", "Block", v(t[1] * 1.45, hgt, t[3] * 1.9), v(0, -(top + hgt / 2), 0), nil, Shroud.Color, "Fabric")
	-- tattered hem: six strips flaring out around the bottom edge
	local hemY = -(bottom + 0.1 * s)
	local w, dz = t[1] * 1.45, t[3] * 1.9
	local strips = {
		{ "TatterFL", -w * 0.25, -dz / 2, v(-12, 0, 0) },
		{ "TatterFR", w * 0.25, -dz / 2, v(-12, 0, 0) },
		{ "TatterBL", -w * 0.25, dz / 2, v(12, 0, 0) },
		{ "TatterBR", w * 0.25, dz / 2, v(12, 0, 0) },
		{ "TatterL", -w / 2, 0, v(0, 0, 12) },
		{ "TatterR", w / 2, 0, v(0, 0, -12) },
	}
	for _, st in strips do
		local side = st[1] == "TatterL" or st[1] == "TatterR"
		add(st[1], "torso", "Block", if side then v(0.08, 0.6 * s, dz * 0.4) else v(w * 0.32, 0.6 * s, 0.08), v(st[2], hemY, st[3]), st[4], Shroud.Edge, "Fabric")
	end
	-- sleeves over the (upper) arms
	if d.arm then
		local a = d.arm
		local sz = if d.r6 then v(a[1] * 1.3, a[2] * 0.75, a[3] * 1.3) else v(a[1] * 1.35, a[2] * 1.1, a[3] * 1.35)
		local py = if d.r6 then a[2] * 0.12 else 0
		add("SleeveL", "leftArm", "Block", sz, v(0, py, 0), nil, Shroud.Color, "Fabric")
		add("SleeveR", "rightArm", "Block", sz, v(0, py, 0), nil, Shroud.Color, "Fabric")
	end
	return out
end

-- Look signature (names, shapes, colours, materials; not sizes): equal for every Phantom.
function Shroud.signature(specs): string
	local parts = {}
	for _, p in specs do
		table.insert(parts, string.format("%s:%s:%s:%s", p.name, p.shape, p.color, p.material))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

Shroud.MaxParts = 16 -- part budget per Phantom

return Shroud
