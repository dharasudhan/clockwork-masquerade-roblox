-- Tiny Instance helpers for the greybox builders.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Style = require(Shared.Config.Style)

local Build = {}

function Build.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Build.color(name: string): Color3
	return Build.rgb(Style.Palette[name] or error("no palette colour " .. name))
end

-- part{ name, size, cf | pos, color, material, parent, shape, collide, transparency, ... }
function Build.part(o): Part
	local p = Instance.new("Part")
	p.Name = o.name or "Part"
	p.Anchored = if o.anchored == nil then true else o.anchored
	p.Size = o.size
	p.CFrame = o.cf or CFrame.new(o.pos or Vector3.zero)
	if o.shape then
		p.Shape = o.shape
	end
	p.Color = if typeof(o.color) == "Color3" then o.color elseif o.color then Build.color(o.color) else Color3.new(1, 1, 1)
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.CanCollide = if o.collide == nil then true else o.collide
	p.CanTouch = o.touch == true
	p.CanQuery = if o.query == nil then true else o.query
	p.CastShadow = if o.shadow == nil then true else o.shadow
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.massless then
		p.Massless = true
	end
	p.Parent = o.parent
	return p
end

function Build.folder(name: string, parent: Instance): Folder
	local f = parent:FindFirstChild(name)
	if f then
		return f :: Folder
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = parent
	return nf
end

-- StreamingEnabled: a Model group that is never streamed out on clients (key interactables:
-- breakers, lift panels, props = cabinets/projector/evidence board/exit console/key pedestals).
-- Same lookups as a Folder (FindFirstChild / GetChildren), but its whole subtree stays replicated.
function Build.persistent(name: string, parent: Instance): Model
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Model") then
		return f
	end
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
	return m
end

function Build.light(parent: Instance, kind: string, color: Color3, brightness: number, range: number, shadows: boolean?)
	local l = Instance.new(kind) :: any
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

function Build.weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
	return w
end

return Build
