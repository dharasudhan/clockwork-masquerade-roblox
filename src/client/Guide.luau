-- The guided first match: very short, kid-friendly steps on the guide card ("Find a chest!",
-- "Fix the red breaker!", "Shine your LAMP!") with a big bouncing arrow over the target and the
-- compass pointing at it. Runs while TutorialDone is false (first match) or after Settings >
-- Replay tutorial; finishes at the end of the first night. Pure step logic (Guide.pick) +
-- a small presenter so tests can check the steps headless.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local Minimap = require(script.Parent.Minimap)

local Guide = {}

local active = false
local found = 0 -- items found this tutorial
local tampered = false
local repaired = false
local sentDone = false
local arrowPart: BasePart? = nil
local arrowGui: BillboardGui? = nil
local onDone: (() -> ())? = nil
local current: any = nil

function Guide.start(done: (() -> ())?)
	active = true
	found, tampered, repaired, sentDone = 0, false, false, false
	onDone = done
end

function Guide.stop()
	active = false
	current = nil
	if arrowPart then
		arrowPart:Destroy()
		arrowPart, arrowGui = nil, nil
	end
	local el = Hud.elements()
	if el.Guide then
		el.Guide.Visible = false
	end
end

function Guide.active(): boolean
	return active
end

function Guide.noteItem()
	found += 1
end
function Guide.noteTamper()
	tampered = true
end
function Guide.noteRepair()
	repaired = true
end

-- Pure: the step to show for this situation. ctx = { phase, who, found, tampered, repaired,
-- tripped (any red breaker), phantomNear, nightNo, stage, carryKey, pages, battery }
function Guide.pick(ctx): { icon: string, text: string, sub: string?, arrow: boolean }?
	local phase, who = ctx.phase, ctx.who
	if phase == "Lobby" or phase == "Results" then
		return nil
	end
	if phase == "Dawn" then
		return { icon = "🌅", text = "Dawn! Get ready for the next night", arrow = false }
	end
	if who == "Wisp" or who == "Bubble" then
		return { icon = "✨", text = "You're a Wisp!", sub = "Tap FLICKER to scare the Phantoms", arrow = false }
	end
	if who == "Phantom" then
		if phase == "Day" then
			if not ctx.tampered then
				return { icon = "⚡", text = "Go to a breaker. TAMPER!", sub = "Stand still. Shh! Act like a guest", arrow = true }
			end
			return { icon = "🤫", text = "Nice! Now blend in", sub = "Open chests like a guest", arrow = true }
		end
		return { icon = "🎭", text = "Tag the guests!", sub = "Get close and tap TAG", arrow = true }
	end
	if who ~= "Guest" then
		return nil
	end
	if phase == "Day" then
		if ctx.found < 1 then
			return { icon = "📦", text = "Find a chest!", sub = "Follow the arrow", arrow = true }
		elseif ctx.found < 3 then
			return { icon = "📦", text = "Great! Find more chests", sub = "Tap an item to see what it does", arrow = true }
		end
		if ctx.nightNo == 2 then
			return { icon = "📜", text = "Find blueprint pages!", sub = "Search the cabinets", arrow = true }
		end
		return { icon = "🗳️", text = "Who is a Phantom?", sub = "Vote at the Evidence Board (Foyer)", arrow = false }
	end
	-- Night
	if ctx.phantomNear then
		return { icon = "🔦", text = "Phantom! Shine your LAMP!", sub = "Light slows them down", arrow = false }
	end
	if ctx.stage == "Overdrive" then
		return { icon = "⭕", text = "Stand in the glowing ring!", sub = "Stay together", arrow = true }
	elseif ctx.stage == "Showdown" then
		if ctx.carryKey then
			return { icon = "🗝️", text = "Run to the Exit Console!", sub = "Ballroom stage", arrow = true }
		end
		return { icon = "🗝️", text = "Find a golden key!", sub = "Follow the arrow", arrow = true }
	end
	if (ctx.pages or 0) > 0 then
		return { icon = "📜", text = "Take the page to the Projector!", sub = "In the Library", arrow = true }
	end
	if ctx.tripped and not ctx.repaired then
		return { icon = "🔧", text = "Fix the RED breaker!", sub = "Follow the arrow, then hold E", arrow = true }
	end
	if ctx.battery ~= nil and ctx.battery < 15 then
		return { icon = "🔋", text = "Lamp low! Use a dry-cell", arrow = false }
	end
	return { icon = "👫", text = "Stay with friends!", sub = "Fix breakers until dawn", arrow = true }
end

local function anyTripped(): boolean
	local s = workspace:GetAttribute("CM_Tripped")
	return type(s) == "string" and s ~= ""
end

local function phantomNear(): boolean
	local me = Players.LocalPlayer
	local c = me and me.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return false
	end
	local pos = r.CFrame.Position
	local function check(m: Instance?)
		local rr = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rr and m:GetAttribute("PState") == "Phantom" then
			local p = rr.CFrame.Position
			return math.abs(p.Y - pos.Y) < 8 and (Vector3.new(p.X - pos.X, 0, p.Z - pos.Z)).Magnitude < 24
		end
		return false
	end
	for _, pl in Players:GetPlayers() do
		if pl ~= me and check(pl.Character) then
			return true
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, b in (if bots then bots:GetChildren() else {}) do
		if check(b) then
			return true
		end
	end
	return false
end

local function arrowAt(goal)
	local cam = workspace.CurrentCamera
	if not goal or not cam then
		if arrowGui then
			arrowGui.Enabled = false
		end
		return
	end
	if not arrowPart then
		local p = Instance.new("Part")
		p.Name = "GuideArrowAnchor"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Parent = cam
		local g = Instance.new("BillboardGui")
		g.Name = "GuideArrow"
		g.Size = UDim2.fromScale(3, 3) -- studs
		g.AlwaysOnTop = true
		g.MaxDistance = 400
		g.Adornee = p
		g.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or p
		local t = Hud.label("Arrow", g, "⬇")
		t.TextColor3 = Hud.rgb("Amber")
		t.TextStrokeTransparency = 0
		arrowPart, arrowGui = p, g
	end
	local bob = math.sin(os.clock() * 4) * 0.6
	;(arrowPart :: BasePart).CFrame = CFrame.new(goal.x, goal.y + 4 + bob, goal.z)
	;(arrowGui :: BillboardGui).Enabled = true
end

function Guide.update()
	local el = Hud.elements()
	if not active or State.inIntro then
		if el.Guide then
			el.Guide.Visible = false
		end
		if arrowGui then
			arrowGui.Enabled = false
		end
		return
	end
	local me = Players.LocalPlayer
	local phase = State.phase()
	local ctx = {
		phase = phase, who = State.who(), found = found, tampered = tampered, repaired = repaired,
		tripped = anyTripped(), phantomNear = State.who() == "Guest" and phase == "Night" and phantomNear(),
		nightNo = workspace:GetAttribute("CM_Night"), stage = workspace:GetAttribute("CM_Stage"),
		carryKey = me and me:GetAttribute("CarryKey"), pages = me and me:GetAttribute("Pages"),
		battery = if phase == "Night" and me then me:GetAttribute("Battery") else nil,
	}
	local step = Guide.pick(ctx)
	current = step
	el.Guide.Visible = step ~= nil
	if step then
		el.Guide.Icon.Text = step.icon
		el.Guide.Text.Text = step.text
		el.Guide.Sub.Text = step.sub or ""
	end
	local goal = step and step.arrow and Minimap.state().goal or nil
	arrowAt(goal)
	-- the tutorial ends with the first night (dawn or dark) or the match result
	if (phase == "Dawn" or phase == "Results") and not sentDone then
		sentDone = true
		if onDone then
			onDone()
		end
	end
	if phase == "Lobby" and sentDone then
		Guide.stop()
	end
end

function Guide.current()
	return current
end

return Guide
