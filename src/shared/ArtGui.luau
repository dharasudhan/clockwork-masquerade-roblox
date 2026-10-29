-- Procedural wall art drawn in a SurfaceGui (no uploaded images needed): framed portraits of
-- (secular, fictional) inventors, landscapes with the manor and airships, blueprints, botanical
-- prints, star charts, clocks, mirrors, banners and wall sconces. One Part per piece (the frame
-- is drawn by the GUI) keeps the part budget phone-friendly. Deterministic per `seed`.
-- When Config/Decor.DecalIds has an uploaded painting for the kind, an ImageLabel shows it instead.
local Shared = script.Parent
local Style = require(Shared.Config.Style)
local Decor = require(Shared.Config.Decor)

local ArtGui = {}

local function rgb(c: any): Color3
	if typeof(c) == "Color3" then
		return c
	end
	local t = if type(c) == "string" then Style.Palette[c] else c
	t = t or { 255, 0, 255 }
	return Color3.fromRGB(t[1], t[2], t[3])
end
ArtGui.rgb = rgb

local function frame(parent: Instance, name: string, x: number, y: number, w: number, h: number, color, opts: any?)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = rgb(color)
	f.BackgroundTransparency = if opts and opts.t then opts.t else 0
	if opts and opts.round then
		local c = Instance.new("UICorner")
		c.CornerRadius = if opts.round == true then UDim.new(0.5, 0) else UDim.new(opts.round, 0)
		c.Parent = f
	end
	if opts and opts.rot then
		f.Rotation = opts.rot
	end
	if opts and opts.stroke then
		local s = Instance.new("UIStroke")
		s.Color = rgb(opts.stroke)
		s.Thickness = opts.thick or 2
		s.Parent = f
		if opts.hollow then
			f.BackgroundTransparency = 1
		end
	end
	f.Parent = parent
	return f
end

local function gradient(f: Frame, a, b, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(rgb(a), rgb(b))
	g.Rotation = rot or 90
	g.Parent = f
end

local function rand(seed: number)
	local s = (seed * 9301 + 49297) % 233280
	return function(): number
		s = (s * 9301 + 49297) % 233280
		return s / 233280
	end
end

local Skin = { { 240, 206, 170 }, { 200, 150, 110 }, { 150, 100, 70 }, { 110, 72, 50 }, { 236, 190, 150 } }
local Hair = { "Silver", "WalnutDark", "Coal", "Copper", "Cream", "Mahogany" }
local Coats = { "TealDeep", "Burgundy", "Forest", "Navy", "Plum", "Ochre" }
local Skies = { { "SkyBlue", "Cream2" }, { "Ochre", "Rose" }, { "Navy", "Plum" }, { "Mint", "Cream2" } }

local Draw = {}
function Draw.portrait(c: Frame, r)
	local bg = frame(c, "Bg", 0, 0, 1, 1, Coats[1 + math.floor(r() * #Coats)])
	gradient(bg, "Charcoal", Coats[1 + math.floor(r() * #Coats)], 90)
	frame(c, "Coat", 0.18, 0.62, 0.64, 0.5, Coats[1 + math.floor(r() * #Coats)], { round = 0.4 })
	frame(c, "Collar", 0.4, 0.6, 0.2, 0.14, "Cream2", { rot = 45 })
	local skin = Skin[1 + math.floor(r() * #Skin)]
	frame(c, "Head", 0.3, 0.24, 0.4, 0.42, skin, { round = true })
	local hair = Hair[1 + math.floor(r() * #Hair)]
	if r() < 0.5 then
		frame(c, "TopHat", 0.3, 0.06, 0.4, 0.2, "Coal", { round = 0.1 })
		frame(c, "HatBand", 0.3, 0.2, 0.4, 0.04, "Brass")
	else
		frame(c, "Hair", 0.28, 0.2, 0.44, 0.14, hair, { round = 0.5 })
	end
	-- brass goggles (the inventor's trademark)
	for _, x in { 0.34, 0.52 } do
		frame(c, "Goggle", x, 0.36, 0.14, 0.12, "TealNeon", { round = true, stroke = "Brass", thick = 3 })
	end
	if r() < 0.6 then
		frame(c, "Moustache", 0.4, 0.54, 0.2, 0.05, hair, { round = 0.5 })
	end
	frame(c, "Gear", 0.66, 0.7, 0.16, 0.16, "Brass", { round = true, stroke = "BrassDark", thick = 2 })
end
function Draw.landscape(c: Frame, r)
	local sky = Skies[1 + math.floor(r() * #Skies)]
	local bg = frame(c, "Sky", 0, 0, 1, 1, sky[1])
	gradient(bg, sky[1], sky[2], 90)
	frame(c, "Sun", 0.68 + r() * 0.1, 0.12, 0.16, 0.26, "Amber", { round = true, t = 0.1 })
	frame(c, "HillBack", -0.2, 0.55, 0.9, 0.7, "Sage", { round = true })
	frame(c, "HillFront", 0.3, 0.62, 1, 0.7, "Forest", { round = true })
	-- the manor on the hill
	frame(c, "Manor", 0.18, 0.42, 0.26, 0.2, "Ivory")
	frame(c, "Roof", 0.16, 0.38, 0.3, 0.06, "Slate")
	frame(c, "Tower", 0.38, 0.26, 0.06, 0.18, "Ivory")
	for k = 0, 2 do
		frame(c, "Window", 0.21 + k * 0.08, 0.47, 0.04, 0.06, "Amber")
	end
	if r() < 0.7 then
		frame(c, "Balloon", 0.55, 0.14, 0.18, 0.12, "Crimson", { round = true })
		frame(c, "Gondola", 0.61, 0.28, 0.06, 0.04, "Walnut")
	end
end
function Draw.airship(c: Frame, r)
	local bg = frame(c, "Sky", 0, 0, 1, 1, "SkyBlue")
	gradient(bg, "Azure", "Cream2", 90)
	for k = 1, 3 do
		frame(c, "Cloud", r() * 0.8, 0.5 + r() * 0.35, 0.24, 0.1, "Cream2", { round = true, t = 0.2 })
	end
	frame(c, "Envelope", 0.18, 0.22, 0.62, 0.26, Coats[1 + math.floor(r() * #Coats)], { round = true })
	frame(c, "Band", 0.46, 0.22, 0.05, 0.26, "Brass")
	frame(c, "Gondola", 0.38, 0.52, 0.24, 0.08, "Walnut", { round = 0.3 })
	frame(c, "Prop", 0.8, 0.3, 0.03, 0.12, "Brass")
end
function Draw.blueprint(c: Frame, r)
	frame(c, "Bg", 0, 0, 1, 1, "Blueprint")
	for k = 1, 7 do
		frame(c, "GridV", k / 8, 0, 0.004, 1, "Cream2", { t = 0.7 })
		frame(c, "GridH", 0, k / 8, 1, 0.006, "Cream2", { t = 0.7 })
	end
	local n = 2 + math.floor(r() * 2)
	for k = 1, n do
		local s = 0.2 + r() * 0.2
		frame(c, "GearOutline", 0.1 + r() * 0.5, 0.1 + r() * 0.4, s, s * 1.3, "Cream2", { round = true, stroke = "Cream2", thick = 2, hollow = true })
	end
	frame(c, "Axle", 0.15, 0.78, 0.7, 0.01, "Cream2")
	local t = Instance.new("TextLabel")
	t.Name = "Caption"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, 0.84)
	t.Size = UDim2.fromScale(0.9, 0.12)
	t.Font = Enum.Font.Code
	t.TextScaled = true
	t.TextColor3 = rgb("Cream2")
	t.Text = string.format("STERLING WORKS - PLAN No. %d", 1 + math.floor(r() * 40))
	t.Parent = c
end
function Draw.botanical(c: Frame, r)
	frame(c, "Bg", 0, 0, 1, 1, "Cream2")
	frame(c, "Stem", 0.49, 0.25, 0.02, 0.65, "Forest")
	for k = 1, 4 do
		local y = 0.3 + k * 0.12
		frame(c, "Leaf", if k % 2 == 0 then 0.5 else 0.26, y, 0.24, 0.08, "Leaf", { round = true, rot = if k % 2 == 0 then -25 else 25 })
	end
	frame(c, "Bloom", 0.38, 0.12, 0.24, 0.18, ({ "Rose", "Amber", "Violet", "Crimson" })[1 + math.floor(r() * 4)], { round = true })
	frame(c, "Pot", 0.38, 0.86, 0.24, 0.1, "Copper", { round = 0.2 })
end
function Draw.starchart(c: Frame, r)
	local bg = frame(c, "Bg", 0, 0, 1, 1, "Navy")
	gradient(bg, "Navy", "Plum", 45)
	frame(c, "Ring", 0.1, 0.1, 0.8, 0.8, "Brass", { round = true, stroke = "Brass", thick = 2, hollow = true })
	for k = 1, 14 do
		local s = 0.02 + r() * 0.025
		frame(c, "Star", 0.12 + r() * 0.76, 0.12 + r() * 0.76, s, s, "Cream2", { round = true })
	end
	frame(c, "Moon", 0.62, 0.2, 0.14, 0.14, "Ivory", { round = true })
end
function Draw.clock(c: Frame, r)
	local face = frame(c, "Face", 0.04, 0.04, 0.92, 0.92, "Cream2", { round = true, stroke = "Brass", thick = 5 })
	for k = 0, 11 do
		local a = k * math.pi / 6
		local mark = frame(face, "Tick", 0.5 + 0.4 * math.sin(a) - 0.02, 0.5 - 0.4 * math.cos(a) - 0.04, 0.04, 0.08, "Coal")
		mark.Rotation = k * 30
	end
	local hr = frame(face, "HourHand", 0.485, 0.28, 0.03, 0.24, "Coal")
	hr.AnchorPoint = Vector2.new(0, 0)
	hr.Rotation = math.floor(r() * 12) * 30
	local mn = frame(face, "MinuteHand", 0.49, 0.14, 0.02, 0.38, "Coal")
	mn.Rotation = math.floor(r() * 12) * 30
	frame(face, "Hub", 0.46, 0.46, 0.08, 0.08, "Brass", { round = true })
end
function Draw.mirror(c: Frame, _r)
	local g = frame(c, "Glass", 0.06, 0.04, 0.88, 0.92, "Silver", { round = 0.45 })
	gradient(g, "Cream2", "SkyBlue", 60)
	frame(g, "Shine", 0.18, 0.12, 0.1, 0.5, "Cream2", { t = 0.4, round = true, rot = 20 })
end
function Draw.banner(c: Frame, r)
	local col = ({ "Burgundy", "TealDeep", "Navy", "Forest", "Plum" })[1 + math.floor(r() * 5)]
	local b = frame(c, "Cloth", 0.08, 0, 0.84, 0.92, col)
	gradient(b, col, "Charcoal", 90)
	frame(c, "Tip", 0.29, 0.82, 0.42, 0.18, col, { rot = 45 })
	frame(c, "Gear", 0.25, 0.25, 0.5, 0.2, "Gold", { round = true, stroke = "BrassDark", thick = 2 })
	frame(c, "Hub", 0.42, 0.31, 0.16, 0.08, "TealNeon", { round = true })
	frame(c, "Stripe", 0.08, 0.6, 0.84, 0.04, "Gold")
end
function Draw.sconce(c: Frame, _r)
	frame(c, "Plate", 0.3, 0.3, 0.4, 0.66, "Brass", { round = 0.3 })
	frame(c, "Flame", 0.36, 0.02, 0.28, 0.34, "Amber", { round = true })
	frame(c, "Glow", 0.42, 0.08, 0.16, 0.2, "Cream2", { round = true })
end

-- Fills `part`'s face with the art piece. Returns the SurfaceGui.
function ArtGui.paint(part: BasePart, face: Enum.NormalId, kind: string, seed: number, decals: any?)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Art"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0.6
	sg.MaxDistance = 90
	sg.Parent = part
	local framed = kind ~= "clock" and kind ~= "sconce" and kind ~= "banner"
	local canvas: Frame
	if framed then
		local outer = frame(sg, "Frame", 0, 0, 1, 1, "Gold")
		gradient(outer, "Gold", "BrassDark", 45)
		canvas = frame(outer, "Canvas", 0.07, 0.06, 0.86, 0.88, "Cream2")
		canvas.ClipsDescendants = true
	else
		canvas = frame(sg, "Canvas", 0, 0, 1, 1, "Cream2", { t = 1 })
	end
	local ids = (decals or Decor.DecalIds)[kind]
	local id = ids and #ids > 0 and ids[(seed % #ids) + 1] or 0
	if id and id ~= 0 then
		local img = Instance.new("ImageLabel")
		img.Name = "Painting"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = "rbxassetid://" .. tostring(id)
		img.ScaleType = Enum.ScaleType.Crop
		img.Parent = canvas
	else
		local draw = Draw[kind] or Draw.landscape
		draw(canvas, rand(seed))
	end
	return sg
end

ArtGui.Kinds = { "portrait", "landscape", "airship", "blueprint", "botanical", "starchart", "clock", "mirror", "banner", "sconce" }

return ArtGui
