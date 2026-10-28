-- Remotes + per-player rate limits. Clients only send intent; the server validates everything.
--   Action (client -> server): (kind: string, arg: any?)
--   Aim    (client -> server): (x, y, z) camera look vector while the lantern is on
--   Notify (server -> client): (payload table) toasts, sfx, role, results
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RateLimiter = require(Shared.Logic.RateLimiter)
local Clock = require(script.Parent.Clock)

local Net = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
Net.Action = Remotes:WaitForChild("Action") :: RemoteEvent
Net.Aim = Remotes:WaitForChild("Aim") :: RemoteEvent
Net.Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local actionLimit = RateLimiter.new(8, 6)
local aimLimit = RateLimiter.new(20, 15)

function Net.allowAction(player: Player): boolean
	return actionLimit:allow(player, Clock.now())
end

function Net.allowAim(player: Player): boolean
	return aimLimit:allow(player, Clock.now())
end

function Net.forget(player: Player)
	actionLimit:forget(player)
	aimLimit:forget(player)
end

function Net.toast(target: any, text: string, color: string?)
	local payload = { kind = "toast", text = text, color = color }
	if target == "all" then
		Net.Notify:FireAllClients(payload)
	elseif typeof(target) == "Instance" and target:IsA("Player") then
		Net.Notify:FireClient(target, payload)
	end
end

function Net.sfx(target: any, cue: string)
	local payload = { kind = "sfx", cue = cue }
	if target == "all" then
		Net.Notify:FireAllClients(payload)
	elseif typeof(target) == "Instance" and target:IsA("Player") then
		Net.Notify:FireClient(target, payload)
	end
end

function Net.send(player: Player, payload)
	Net.Notify:FireClient(player, payload)
end

return Net
