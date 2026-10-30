-- The story intro ("Break In"-style): a skippable cinematic of camera pans around Sterling
-- Manor with dialogue bubbles from Bellows the butler and Professor Sterling, the inventor.
-- Plays at the START OF EVERY SESSION since v1.4 (before v1.4: first visit only) and from
-- Settings > Replay story intro. The IntroSeen attribute is still sent to the server for
-- stats, but it no longer gates the cinematic.
-- Step-driven (Intro.step(dt) from Heartbeat) so it is deterministic and testable headless.
-- Skip: the SKIP button, gamepad B / A, keyboard Space / Backspace.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)

local Intro = {}

local rgb = Hud.rgb

local Speakers = {
	Bellows = { name = "Bellows the Butler", icon = "🤵", color = "Cream2" },
	Sterling = { name = "Professor Sterling", icon = "🎩", color = "Brass" },
}

-- Each shot: camera from -> to (positions) looking at `look`, seconds, speaker, line (short,
-- simple words for young players).
Intro.Shots = {
	{ from = Vector3.new(0, 34, 178), to = Vector3.new(0, 24, 150), look = Vector3.new(0, 22, 40), seconds = 5, speaker = "Bellows",
		line = "Welcome to Sterling Manor! I am Bellows, the butler." },
	{ from = Vector3.new(-26, 14, 96), to = Vector3.new(10, 9, 76), look = Vector3.new(-9, 7, 60), seconds = 5, speaker = "Sterling",
		line = "And I'm Professor Sterling, the inventor! Welcome to my clockwork masquerade!" },
	{ from = Vector3.new(-24, 13, 56), to = Vector3.new(4, 10, 42), look = Vector3.new(-10, 5, 30), seconds = 5, speaker = "Bellows",
		line = "Everyone wears a mask... but some guests are PHANTOMS in disguise!" },
	{ from = Vector3.new(0, 32, 26), to = Vector3.new(0, 26, -8), look = Vector3.new(0, 2, -4), seconds = 5, speaker = "Sterling",
		line = "At night they break my power. Fix the RED breakers to bring back the light!" },
	-- v1.2: witness tells - the sound of a dying breaker IS evidence (ExposeService.tampered,
	-- 16-stud radius). Camera reuses shot 3's known-good path in reverse (pull back, not push in).
	{ from = Vector3.new(4, 10, 42), to = Vector3.new(-24, 13, 56), look = Vector3.new(-10, 5, 30), seconds = 5, speaker = "Bellows",
		line = "If you HEAR a breaker die nearby, someone is close! Remember where you stood." },
	{ from = Vector3.new(6, -7, 22), to = Vector3.new(32, -8, -8), look = Vector3.new(20, -16, 2), seconds = 4.5, speaker = "Sterling",
		line = "Breakers hide everywhere: down in the boiler level..." },
	{ from = Vector3.new(16, 74, -28), to = Vector3.new(34, 70, -34), look = Vector3.new(27, 62, -57), seconds = 4.5, speaker = "Sterling",
		line = "...and up in my tower! Open chests by day to find gadgets." },
	{ from = Vector3.new(70, 64, 130), to = Vector3.new(40, 48, 150), look = Vector3.new(0, 20, 0), seconds = 5, speaker = "Bellows",
		line = "Survive three nights and help the Dawn Reboot. Good luck, guests!" },
}

local box: Frame = nil :: any
local bars: { Frame } = {}
local playing = false
local shot, t = 1, 0
local onDone: ((boolean) -> ())? = nil
local savedType: any = nil

local function ui()
	if box then
		return
	end
	local gui = Hud.gui()
	for i, y in { 0, 0.88 } do
		local b = Instance.new("Frame")
		b.Name = "Letterbox" .. i
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Size = UDim2.fromScale(1, 0.12)
		b.Position = UDim2.fromScale(0, y)
		b.ZIndex = 30
		b.Visible = false
		b.Parent = gui
		table.insert(bars, b)
	end
	box = Hud.panel("Dialogue", "WalnutDark", 0.05, gui)
	box.ZIndex = 31
	box.Visible = false
	local st = Instance.new("UIStroke")
	st.Color = rgb("Brass")
	st.Thickness = 3
	st.Parent = box
	local portrait = Hud.panel("Portrait", "TealDeep", 0, box)
	portrait.Size = UDim2.fromScale(0.16, 0.86)
	portrait.Position = UDim2.fromScale(0.015, 0.07)
	portrait.ZIndex = 32
	local pa = Instance.new("UIAspectRatioConstraint")
	pa.AspectRatio = 1
	pa.Parent = portrait
	Hud.label("Icon", portrait, "").ZIndex = 33
	local nm = Hud.label("Speaker", box, "")
	nm.Size = UDim2.fromScale(0.6, 0.26)
	nm.Position = UDim2.fromScale(0.2, 0.06)
	nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.Font = Enum.Font.Sarpanch
	nm.ZIndex = 32
	local tx = Hud.label("Line", box, "")
	tx.Size = UDim2.fromScale(0.62, 0.6)
	tx.Position = UDim2.fromScale(0.2, 0.34)
	tx.TextXAlignment = Enum.TextXAlignment.Left
	tx.TextYAlignment = Enum.TextYAlignment.Top
	tx.TextWrapped = true
	tx.Font = Enum.Font.GothamBold
	tx.ZIndex = 32
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromScale(0.14, 0.34)
	skip.Position = UDim2.fromScale(0.845, 0.6)
	skip.BackgroundColor3 = rgb("Copper")
	skip.TextColor3 = rgb("Cream")
	skip.Font = Enum.Font.GothamBlack
	skip.TextScaled = true
	skip.Text = "SKIP ▶▶"
	skip.Selectable = true
	skip.ZIndex = 33
	skip.Parent = box
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = skip
	skip.Activated:Connect(function()
		Intro.stop(true)
	end)
end

local function camPose(s, a: number): CFrame
	local p = s.from:Lerp(s.to, a)
	return CFrame.lookAt(p, s.look)
end

local function showShot(i: number)
	local s = Intro.Shots[i]
	local sp = Speakers[s.speaker]
	box.Portrait.Icon.Text = sp.icon
	box.Speaker.Text = sp.name
	box.Speaker.TextColor3 = rgb(sp.color)
	box.Line.Text = ""
end

function Intro.start(done: ((boolean) -> ())?)
	ui()
	onDone = done
	playing = true
	State.inIntro = true
	shot, t = 1, 0
	local r = Hud.layout() and Hud.layout().modal.Dialogue
	if r then
		box.Position = UDim2.fromOffset(math.floor(r.x), math.floor(r.y))
		box.Size = UDim2.fromOffset(math.floor(r.w), math.floor(r.h))
	end
	box.Visible = true
	for _, b in bars do
		b.Visible = true
	end
	pcall(function()
		local cam = workspace.CurrentCamera
		savedType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = camPose(Intro.Shots[1], 0)
	end)
	showShot(1)
	ContextActionService:BindActionAtPriority("CM_skipIntro", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Intro.stop(true)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 4000, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonA, Enum.KeyCode.Space, Enum.KeyCode.Backspace)
	if Input.device() == "gamepad" then
		pcall(function()
			GuiService.SelectedObject = box.Skip
		end)
	end
end

function Intro.step(dt: number)
	if not playing then
		return
	end
	t += dt
	local s = Intro.Shots[shot]
	local a = math.clamp(t / s.seconds, 0, 1)
	local eased = a * a * (3 - 2 * a)
	pcall(function()
		workspace.CurrentCamera.CFrame = camPose(s, eased)
	end)
	-- typewriter: the whole line within the first 60% of the shot
	local n = math.floor(#s.line * math.clamp(a / 0.6, 0, 1))
	box.Line.Text = string.sub(s.line, 1, n)
	if t >= s.seconds then
		shot += 1
		t = 0
		if shot > #Intro.Shots then
			Intro.stop(false)
		else
			showShot(shot)
		end
	end
end

function Intro.stop(skipped: boolean)
	if not playing then
		return
	end
	playing = false
	State.inIntro = false
	box.Visible = false
	for _, b in bars do
		b.Visible = false
	end
	ContextActionService:UnbindAction("CM_skipIntro")
	pcall(function()
		local cam = workspace.CurrentCamera
		cam.CameraType = savedType or Enum.CameraType.Custom
		GuiService.SelectedObject = nil
	end)
	if onDone then
		onDone(skipped)
	end
end

function Intro.playing(): boolean
	return playing
end

function Intro.progress(): (number, number)
	return shot, t
end

function Intro.box(): Frame
	return box
end

return Intro
