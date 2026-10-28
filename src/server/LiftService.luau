-- The service lift: one shaft with a stop on every floor (Config/Manor rooms with `lift`). Riders
-- use the "Up"/"Down" ProximityPrompts on the brass panel; bots ride through the same entry
-- point when a route waypoint says `lift = level`. Server-validated: in a lift stop, one floor at
-- a time, a short cooldown, not while caught in an Energy Bubble.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Participants = require(script.Parent.Participants)
local ManorBuilder = require(script.Parent.ManorBuilder)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local LiftService = {}

LiftService.Cooldown = 2

local function stops(liftName: string)
	local out = {}
	for _, r in Manor.Rooms do
		if r.lift == liftName then
			out[r.level] = r
		end
	end
	return out
end

-- Ride from the lift stop p stands in to `toLevel` (must be the next floor up or down).
function LiftService.ride(p, toLevel: any): boolean
	if type(toLevel) ~= "number" or toLevel ~= toLevel then
		return false
	end
	local ph = workspace:GetAttribute("CM_Phase")
	if (ph ~= "Day" and ph ~= "Night") or p.state == "Bubble" then
		return false
	end
	local now = Clock.now()
	if p.liftAt and now - p.liftAt < LiftService.Cooldown then
		return false
	end
	local root = Participants.root(p)
	if not root then
		return false
	end
	local pos = root.CFrame.Position
	local here = ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
	local r = here and ManorLayout.ids(Manor)[here]
	if not r or not r.lift or math.abs(toLevel - r.level) ~= 1 then
		return false
	end
	local dest = stops(r.lift)[toLevel]
	if not dest then
		return false
	end
	p.liftAt = now
	local dy = (dest.level - r.level) * Manor.LevelHeight
	local cx, cz = ManorLayout.centre(dest)
	local x, z = ManorLayout.clampInto(dest, pos.X, pos.Z, 2.5)
	if math.abs(x - cx) + math.abs(z - cz) > 8 then
		x, z = cx, cz
	end
	p.model:PivotTo(CFrame.new(x, pos.Y + dy, z) * (root.CFrame - root.CFrame.Position))
	if p.player then
		Net.sfx(p.player, "Click")
		Net.toast(p.player, "Lift: " .. ManorLayout.levelName(Manor, dest.level), "Brass")
	end
	p.stats.lifts = (p.stats.lifts or 0) + 1
	return true
end

function LiftService.init()
	local built = ManorBuilder.get()
	if not built then
		return
	end
	for roomId, h in built.lifts do
		local r = ManorLayout.ids(Manor)[roomId]
		local all = stops(r.lift)
		for _, dir in { 1, -1 } do
			local dest = all[r.level + dir]
			if dest and not h.prompt:FindFirstChild(if dir > 0 then "LiftUp" else "LiftDown") then
				local pr = Instance.new("ProximityPrompt")
				pr.Name = if dir > 0 then "LiftUp" else "LiftDown"
				pr.ActionText = (if dir > 0 then "Up to " else "Down to ") .. ManorLayout.levelName(Manor, dest.level)
				pr.ObjectText = "Service Lift"
				pr.HoldDuration = 0.3
				pr.MaxActivationDistance = 9
				pr.RequiresLineOfSight = false
				pr.KeyboardKeyCode = if dir > 0 then Enum.KeyCode.E else Enum.KeyCode.R
				pr.UIOffset = Vector2.new(0, if dir > 0 then -40 else 40)
				pr:SetAttribute("ForRole", "Any")
				pr:SetAttribute("AllowWisp", true)
				pr.Parent = h.prompt
				local level = dest.level
				pr.Triggered:Connect(function(player)
					local p = Participants.ofPlayer(player)
					if p then
						LiftService.ride(p, level)
					end
				end)
			end
		end
	end
end

return LiftService
