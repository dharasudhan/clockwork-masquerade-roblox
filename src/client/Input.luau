-- One input map for keyboard, gamepad and touch (ContextActionService). Actions, not keys:
--   primary  F / RT (R2) / touch button      Guest night: lantern · Phantom night: TAG · Wisp: FLICKER
--   use      V / Y                           use the selected item
--   gadget   G / B                           class gadget (Barricade / Strobe), Phantom GLIDE / DASH, Wisp SLICK
--   prev     Q / LB / D-pad left             previous item in the hotbar
--   next     E / RB / D-pad right            next item (E only when no ProximityPrompt is showing,
--                                             so E still opens chests, breakers, the lift ...)
--   slot1-9  1..9                            pick a hotbar slot directly
--   info     I / D-pad up                    items panel (what each item does)
--   menu     M / D-pad down                  shop / class / settings
--   legacy   C dry-cell, Z flicker, X slick, LT (L2) lantern
-- Interact stays on Roblox's ProximityPrompt keys (E on keyboard, X on gamepad).
-- Button-prompt glyphs: Input.glyph(action) returns the label (and on gamepad the Roblox glyph
-- image) for the last-used input device, so the HUD always shows the right button.
-- Approach compared with nezuo/spark and AdamMillsy/Inputter (both MIT): one action table, many
-- bindings, device-aware hints. Written from scratch on ContextActionService.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Input = {}

local K = Enum.KeyCode
Input.Bindings = {
	primary = { K.F, K.ButtonR2 },
	use = { K.V, K.ButtonY },
	gadget = { K.G, K.ButtonB },
	prev = { K.Q, K.ButtonL1, K.DPadLeft },
	next = { K.E, K.ButtonR1, K.DPadRight },
	info = { K.I, K.DPadUp },
	menu = { K.M, K.DPadDown },
	cell = { K.C },
	flicker = { K.Z },
	slick = { K.X },
	lantern = { K.ButtonL2 },
}
Input.Order = { "primary", "use", "gadget", "prev", "next", "info", "menu", "cell", "flicker", "slick", "lantern" }
local SlotKeys = { K.One, K.Two, K.Three, K.Four, K.Five, K.Six, K.Seven, K.Eight, K.Nine }

local GamepadText = { primary = "RT", use = "Y", gadget = "B", prev = "LB", next = "RB", info = "▲", menu = "▼", lantern = "LT", interact = "X" }
local KeyText = { primary = "F", use = "V", gadget = "G", prev = "Q", next = "E", info = "I", menu = "M", lantern = "F", interact = "E" }
local GamepadKey = { primary = K.ButtonR2, use = K.ButtonY, gadget = K.ButtonB, prev = K.ButtonL1, next = K.ButtonR1, info = K.DPadUp, menu = K.DPadDown, lantern = K.ButtonL2, interact = K.ButtonX }

local handler: ((string, any?) -> ())? = nil
local device = "keyboard" -- "keyboard" | "gamepad" | "touch"
local promptsShown = 0
local log: { string } = {} -- actions fired (tests read it)

function Input.device(): string
	return device
end

function Input.setDevice(d: string)
	device = d
end

function Input.log()
	return log
end

local function fire(action: string, arg: any?)
	table.insert(log, action)
	if #log > 50 then
		table.remove(log, 1)
	end
	if handler then
		handler(action, arg)
	end
end

-- The CAS callback (exposed so headless tests can drive it with fake input objects).
function Input.onAction(actionName: string, inputState: Enum.UserInputState, inputObject: any): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local kc = inputObject and inputObject.KeyCode
	if actionName == "CM_next" and kc == K.E and promptsShown > 0 then
		return Enum.ContextActionResult.Pass -- E belongs to the prompt on screen
	end
	if string.sub(actionName, 1, 7) == "CM_slot" then
		fire("slot", tonumber(string.sub(actionName, 8)))
		return Enum.ContextActionResult.Sink
	end
	fire(string.sub(actionName, 4))
	return Enum.ContextActionResult.Sink
end

function Input.bind(cb: (string, any?) -> ())
	handler = cb
	for _, a in Input.Order do
		ContextActionService:BindAction("CM_" .. a, Input.onAction, false, table.unpack(Input.Bindings[a]))
	end
	for i, kc in SlotKeys do
		ContextActionService:BindAction("CM_slot" .. i, Input.onAction, false, kc)
	end
	pcall(function()
		UserInputService.LastInputTypeChanged:Connect(function(t)
			Input.noteInputType(t)
		end)
		ProximityPromptService.PromptShown:Connect(function()
			promptsShown += 1
		end)
		ProximityPromptService.PromptHidden:Connect(function()
			promptsShown = math.max(0, promptsShown - 1)
		end)
	end)
	pcall(function()
		if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
			device = "gamepad"
		elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			device = "touch"
		end
	end)
end

function Input.noteInputType(t: Enum.UserInputType)
	local name = t.Name
	if string.sub(name, 1, 7) == "Gamepad" then
		device = "gamepad"
	elseif name == "Touch" then
		device = "touch"
	elseif name == "Keyboard" or string.sub(name, 1, 5) == "Mouse" then
		device = "keyboard"
	end
end

function Input.setPromptsShown(n: number)
	promptsShown = n
end

-- Label (+ optional glyph image id) for an action on the current device; touch -> nil.
function Input.glyph(action: string): (string?, string?)
	if device == "gamepad" then
		local img = nil
		local kc = GamepadKey[action]
		if kc then
			pcall(function()
				img = UserInputService:GetImageForKeyCode(kc)
			end)
		end
		return GamepadText[action], img
	elseif device == "keyboard" then
		return KeyText[action], nil
	end
	return nil, nil
end

return Input
