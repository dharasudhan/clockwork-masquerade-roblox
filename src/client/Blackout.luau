-- v1.4.1 Dawn Scatter: the clock-strike blackout. A full-screen black frame (above the HUD,
-- under nothing, ignores the inset so notches/console overscan stay black too) fades in, holds
-- while the server swaps appearances and positions, and fades out. Purely visual and
-- server-driven (Notify kind "blackout"): no input is needed, so touch, keyboard and gamepad
-- all behave the same, and nothing can be selected underneath it (Active = false, no buttons).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Scatter = require(Shared.Logic.Scatter)
local Style = require(Shared.Config.Style)

local Blackout = {}

local gui: ScreenGui? = nil
local frame: Frame? = nil
local caption: TextLabel? = nil
local startedAt: number? = nil
local cfg = Scatter.Timing

function Blackout.build(playerGui: Instance)
	local g = Instance.new("ScreenGui")
	g.Name = "CM_Blackout"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 50
	g.Enabled = false
	local f = Instance.new("Frame")
	f.Name = "Black"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = g
	local c = Instance.new("TextLabel")
	c.Name = "Caption"
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromScale(0.8, 0.08)
	c.BackgroundTransparency = 1
	c.Font = Enum.Font.GothamBlack
	c.TextScaled = true
	local b = Style.Palette.Brass
	c.TextColor3 = Color3.fromRGB(b[1], b[2], b[3])
	c.TextTransparency = 1
	c.Text = "🕰  THE CLOCK STRIKES...  EVERYONE IS SCATTERED"
	c.Parent = f
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 34
	lim.MinTextSize = 12
	lim.Parent = c
	g.Parent = playerGui
	gui, frame, caption = g, f, c
end

-- payload from the server: { total, fadeIn, fadeOut } (falls back to Logic/Scatter.Timing)
function Blackout.play(payload: any?, now: number)
	local p = if type(payload) == "table" then payload else {}
	cfg = {
		Total = tonumber(p.total) or Scatter.Timing.Total,
		FadeIn = tonumber(p.fadeIn) or Scatter.Timing.FadeIn,
		FadeOut = tonumber(p.fadeOut) or Scatter.Timing.FadeOut,
		SwapAt = Scatter.Timing.SwapAt,
	}
	startedAt = now
	if gui then
		gui.Enabled = true
	end
end

-- called every frame; returns the current blackness 0..1
function Blackout.step(now: number): number
	if startedAt == nil then
		return 0
	end
	local t = now - (startedAt :: number)
	local a = Scatter.alpha(t, cfg)
	if frame then
		frame.BackgroundTransparency = 1 - a
	end
	if caption then
		caption.TextTransparency = 1 - a * 0.9
	end
	if t >= cfg.Total then
		startedAt = nil
		if gui then
			gui.Enabled = false
		end
		return 0
	end
	return a
end

function Blackout.active(): boolean
	return startedAt ~= nil
end

function Blackout.gui(): ScreenGui?
	return gui
end

return Blackout
