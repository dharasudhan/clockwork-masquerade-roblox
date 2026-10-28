-- Shows each ProximityPrompt only to those who may use it (attributes ForRole / ForPhase /
-- NeedsTripped / Done set by the server). Purely cosmetic: the server validates every
-- trigger. Enabled is set locally, so other players never learn who sees a Tamper prompt.
local State = require(script.Parent.State)

local PromptFilter = {}

function PromptFilter.allowed(prompt: Instance, phase: string, role: string?, pstate: string?): boolean
	if prompt:GetAttribute("Done") then
		return false
	end
	local forPhase = prompt:GetAttribute("ForPhase")
	if forPhase and forPhase ~= phase then
		return false
	end
	if pstate == "Wisp" or pstate == "Bubble" or role == nil then
		return false
	end
	local forRole = prompt:GetAttribute("ForRole")
	if forRole and forRole ~= "Any" and forRole ~= role then
		return false
	end
	if prompt:GetAttribute("NeedsTripped") then
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		if not (model and model:GetAttribute("Tripped")) then
			return false
		end
	end
	return true
end

function PromptFilter.refresh()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local phase = State.phase()
	local role = if State.inMatch() then State.role else nil
	local pstate = State.pstate()
	for _, d in map:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			local ok = PromptFilter.allowed(d, phase, role, pstate)
			if d.Enabled ~= ok then
				d.Enabled = ok
			end
		end
	end
end

return PromptFilter
