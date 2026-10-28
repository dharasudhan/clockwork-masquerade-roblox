-- The Clockwork Masquerade - client entry: HUD, controls (buttons + keys), lantern aim,
-- prompt filter, music/SFX. Keys: F lantern, V use item, B next item, C dry-cell, G glow-stick,
-- Q tag, Z flicker, X slick, E/R lift up/down (prompts).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("Action") :: RemoteEvent
local Aim = Remotes:WaitForChild("Aim") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local State = require(script:WaitForChild("State"))
local Hud = require(script:WaitForChild("Hud"))
local PromptFilter = require(script:WaitForChild("PromptFilter"))
local SoundManager = require(script:WaitForChild("SoundManager"))

local player = Players.LocalPlayer
Hud.build(player:WaitForChild("PlayerGui"))
SoundManager.init()

local function send(kind: string, arg: any?)
	Action:FireServer(kind, arg)
end
local function cycleItem()
	State.cycle(Hud.usableItems(State.phase(), player:GetAttributes()))
	Hud.update()
end
local function useItem(item: string?)
	local id = item or State.selected
	if id then
		send("use", id)
	end
end
Hud.onButton(function(action, item)
	SoundManager.sfx("Click")
	if action == "next" then
		cycleItem()
	elseif action == "use" then
		useItem(item)
	else
		send(action)
	end
end)

local Keys = {
	[Enum.KeyCode.F] = "lantern",
	[Enum.KeyCode.C] = "cell",
	[Enum.KeyCode.G] = "glow",
	[Enum.KeyCode.Q] = "tag",
	[Enum.KeyCode.Z] = "flicker",
	[Enum.KeyCode.X] = "slick",
	[Enum.KeyCode.ButtonR2] = "tag",
	[Enum.KeyCode.ButtonL2] = "lantern",
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.ButtonX then
		useItem(nil)
		return
	elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.DPadRight then
		cycleItem()
		return
	end
	local a = Keys[input.KeyCode]
	if a then
		send(a)
	end
end)

Notify.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "toast" then
		State.toast = { text = tostring(payload.text), color = payload.color, at = os.clock() }
	elseif payload.kind == "sfx" then
		SoundManager.sfx(tostring(payload.cue))
	elseif payload.kind == "role" then
		State.role = payload.role
		State.mates = payload.mates or {}
		State.results = nil
		Hud.showRole(payload.role, payload.mates)
	elseif payload.kind == "channel" then
		State.channel = if payload.channel then payload else nil
	elseif payload.kind == "results" then
		State.results = payload
		State.channel = nil
	end
end)

local lastPhase = nil
local aimAccum, uiAccum, promptAccum = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	aimAccum += dt
	uiAccum += dt
	promptAccum += dt
	local phase = State.phase()
	if phase ~= lastPhase then
		lastPhase = phase
		SoundManager.setPhase(phase)
		if phase == "Lobby" then
			State.role = nil
			State.channel = nil
		elseif phase == "Day" and State.role == nil then
			send("whoami")
		end
	end
	if aimAccum >= 0.1 then
		aimAccum = 0
		if player:GetAttribute("LanternOn") then
			local cam = workspace.CurrentCamera
			if cam then
				local v = cam.CFrame.LookVector
				Aim:FireServer(v.X, v.Y, v.Z)
			end
		end
	end
	if uiAccum >= 0.1 then
		uiAccum = 0
		Hud.update()
	end
	if promptAccum >= 0.3 then
		promptAccum = 0
		PromptFilter.refresh()
	end
end)
send("whoami")
