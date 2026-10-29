-- Small models that look like each item (held in the right hand when selected, popped out of a
-- chest when found): a wrench, a pocket watch on a chain, a pair of boots, a dry-cell battery, a
-- glow-stick, a smoke pellet, a bell, a coil of copper wire, a wind-up decoy toy, a blueprint
-- page and a golden key. Built from a few parts each (phone-friendly). Returns a Model whose
-- PrimaryPart is "Handle" (centre of the grip).
local Shared = script.Parent
local Style = require(Shared.Config.Style)

local ItemModels = {}

local function rgb(name: string): Color3
	local c = Style.Palette[name] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(m: Model, name: string, size: Vector3, cf: CFrame, color: string, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Color = rgb(color)
	p.Material = material or Enum.Material.Metal
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local Cyl, Ball = Enum.PartType.Cylinder, Enum.PartType.Ball
local Up = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y

local Builders = {}
function Builders.wrench(m)
	local h = part(m, "Handle", Vector3.new(0.25, 1.4, 0.12), CFrame.new(), "Brass")
	part(m, "JawL", Vector3.new(0.18, 0.4, 0.12), CFrame.new(-0.22, 0.85, 0), "Brass")
	part(m, "JawR", Vector3.new(0.18, 0.4, 0.12), CFrame.new(0.22, 0.85, 0), "Brass")
	part(m, "Bridge", Vector3.new(0.62, 0.16, 0.12), CFrame.new(0, 0.62, 0), "Brass")
	return h
end
function Builders.watch(m)
	local h = part(m, "Handle", Vector3.new(0.12, 0.8, 0.8), CFrame.Angles(0, math.rad(90), 0), "Gold", nil, Cyl)
	part(m, "Face", Vector3.new(0.13, 0.62, 0.62), CFrame.new(0, 0, -0.01) * CFrame.Angles(0, math.rad(90), 0), "Cream2", Enum.Material.SmoothPlastic, Cyl)
	part(m, "Crown", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 0.46, 0), "Gold", nil, Ball)
	part(m, "Chain", Vector3.new(0.06, 0.6, 0.06), CFrame.new(0.1, 0.8, 0) * CFrame.Angles(0, 0, math.rad(20)), "Gold")
	return h
end
function Builders.boots(m)
	local h = part(m, "Handle", Vector3.new(0.35, 0.8, 0.45), CFrame.new(-0.2, 0, 0), "Mahogany", Enum.Material.Fabric)
	part(m, "Toe", Vector3.new(0.35, 0.3, 0.75), CFrame.new(-0.2, -0.25, -0.25), "Mahogany", Enum.Material.Fabric)
	part(m, "Boot2", Vector3.new(0.35, 0.8, 0.45), CFrame.new(0.25, 0, 0), "Mahogany", Enum.Material.Fabric)
	part(m, "Toe2", Vector3.new(0.35, 0.3, 0.75), CFrame.new(0.25, -0.25, -0.25), "Mahogany", Enum.Material.Fabric)
	part(m, "Spring", Vector3.new(0.3, 0.2, 0.2), CFrame.new(-0.2, -0.5, 0) * Up, "Spring", Enum.Material.Neon, Cyl)
	part(m, "Spring2", Vector3.new(0.3, 0.2, 0.2), CFrame.new(0.25, -0.5, 0) * Up, "Spring", Enum.Material.Neon, Cyl)
	return h
end
function Builders.cell(m)
	local h = part(m, "Handle", Vector3.new(1, 0.5, 0.5), Up, "Warm", Enum.Material.SmoothPlastic, Cyl)
	part(m, "Cap", Vector3.new(0.12, 0.3, 0.3), CFrame.new(0, 0.55, 0) * Up, "Silver", nil, Cyl)
	part(m, "Band", Vector3.new(0.3, 0.52, 0.52), CFrame.new(0, -0.2, 0) * Up, "Coal", Enum.Material.SmoothPlastic, Cyl)
	return h
end
function Builders.glow(m)
	local h = part(m, "Handle", Vector3.new(1.1, 0.22, 0.22), Up, "Glow", Enum.Material.Neon, Cyl)
	part(m, "Tip", Vector3.new(0.15, 0.24, 0.24), CFrame.new(0, 0.6, 0) * Up, "Silver", nil, Cyl)
	return h
end
function Builders.smoke(m)
	local h = part(m, "Handle", Vector3.new(0.55, 0.55, 0.55), CFrame.new(), "Smoke", Enum.Material.SmoothPlastic, Ball)
	part(m, "Fuse", Vector3.new(0.25, 0.08, 0.08), CFrame.new(0, 0.35, 0) * Up, "Amber", Enum.Material.Neon, Cyl)
	return h
end
function Builders.bell(m)
	local h = part(m, "Handle", Vector3.new(0.6, 0.7, 0.7), Up, "Bell", Enum.Material.Metal, Cyl)
	part(m, "Rim", Vector3.new(0.12, 0.85, 0.85), CFrame.new(0, -0.33, 0) * Up, "Gold", nil, Cyl)
	part(m, "Knob", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.42, 0), "Gold", nil, Ball)
	return h
end
function Builders.wire(m)
	local h = part(m, "Handle", Vector3.new(0.5, 0.8, 0.8), CFrame.new(), "Copper", nil, Cyl)
	part(m, "Hole", Vector3.new(0.52, 0.3, 0.3), CFrame.new(), "Coal", Enum.Material.SmoothPlastic, Cyl)
	part(m, "Tail", Vector3.new(0.06, 0.6, 0.06), CFrame.new(0, 0.55, 0.25) * CFrame.Angles(math.rad(30), 0, 0), "Copper")
	return h
end
function Builders.decoy(m)
	local h = part(m, "Handle", Vector3.new(0.7, 0.6, 0.6), Up, "Copper", nil, Cyl)
	part(m, "Head", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0.55, 0), "Decoy", Enum.Material.Neon, Ball)
	part(m, "Key", Vector3.new(0.08, 0.3, 0.45), CFrame.new(0.38, 0.05, 0), "Brass")
	return h
end
function Builders.page(m)
	return part(m, "Handle", Vector3.new(0.8, 1, 0.04), CFrame.new(), "Blueprint", Enum.Material.SmoothPlastic)
end
function Builders.key(m)
	local h = part(m, "Handle", Vector3.new(0.14, 1.2, 0.14), CFrame.new(), "Gold", Enum.Material.Neon)
	part(m, "Bow", Vector3.new(0.12, 0.5, 0.5), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, math.rad(90), 0), "Gold", Enum.Material.Neon, Cyl)
	part(m, "Bit", Vector3.new(0.12, 0.2, 0.3), CFrame.new(0, -0.5, -0.18), "Gold", Enum.Material.Neon)
	return h
end

ItemModels.Kinds = { "wrench", "watch", "boots", "cell", "glow", "smoke", "bell", "wire", "decoy", "page", "key" }

function ItemModels.build(kind: string): Model?
	local b = Builders[kind]
	if not b then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Item_" .. kind
	local handle = b(m)
	-- weld every part to the handle (keeps relative layout when the model moves)
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = d
			w.Parent = d
		end
	end
	m.PrimaryPart = handle
	return m
end

return ItemModels
