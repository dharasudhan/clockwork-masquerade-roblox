--!strict
-- Builds a BillboardGui from Config/Billboards (stud-sized, behind walls, short range).
-- Children must use SCALE sizes (the gui has no pixel size).

local Specs = require(script.Parent.Config.Billboards)

local Billboard = {}

function Billboard.new(kind: string, name: string?): BillboardGui
	local s = Specs[kind] or error("unknown billboard kind " .. kind)
	local gui = Instance.new("BillboardGui")
	gui.Name = name or "Label"
	gui.Size = UDim2.fromScale(s.w, s.h)
	gui.AlwaysOnTop = s.alwaysOnTop == true
	gui.MaxDistance = s.maxDistance
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui:SetAttribute("BillboardKind", kind)
	return gui
end

-- Re-applies a kind to an existing gui (e.g. a ghost label promoted to the King's).
function Billboard.apply(gui: BillboardGui, kind: string)
	local s = Specs[kind] or error("unknown billboard kind " .. kind)
	gui.Size = UDim2.fromScale(s.w, s.h)
	gui.AlwaysOnTop = s.alwaysOnTop == true
	gui.MaxDistance = s.maxDistance
	gui:SetAttribute("BillboardKind", kind)
end

return Billboard
