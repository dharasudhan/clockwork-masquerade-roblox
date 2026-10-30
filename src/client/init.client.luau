-- The Clockwork Masquerade - client entry: HUD, one input map for touch / keyboard / gamepad
-- (Input), menus (shop, class, settings, quests, vote, items), the story intro, the guided
-- first match, lantern aim, prompt filter, music/SFX. Controls: see Input.luau.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("Action") :: RemoteEvent
local Aim = Remotes:WaitForChild("Aim") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)

local State = require(script:WaitForChild("State"))
local Hud = require(script:WaitForChild("Hud"))
local Input = require(script:WaitForChild("Input"))
local Menus = require(script:WaitForChild("Menus"))
local Intro = require(script:WaitForChild("Intro"))
local Guide = require(script:WaitForChild("Guide"))
local PromptFilter = require(script:WaitForChild("PromptFilter"))
local SoundManager = require(script:WaitForChild("SoundManager"))

local player = Players.LocalPlayer
Hud.build(player:WaitForChild("PlayerGui"))
SoundManager.init()

local function send(kind: string, arg: any?)
	Action:FireServer(kind, arg)
end

local function startTutorial()
	Guide.start(function()
		send("tutorialDone")
	end)
end

local function playIntro(thenTutorial: boolean)
	Menus.close()
	Intro.start(function()
		send("introDone")
		if thenTutorial and player:GetAttribute("TutorialDone") ~= true then
			startTutorial()
		end
	end)
end

Menus.init(send, function(what)
	if what == "intro" then
		playIntro(false)
	elseif what == "tutorial" then
		startTutorial()
		State.toast = { text = "Tutorial on! Follow the arrows in your next match.", color = "Amber", at = os.clock() }
	end
end)

local lastHeld: string? = nil
local function syncHeld()
	local want = if State.who() == "Guest" or (State.who() == "Phantom" and State.phase() == "Day") then State.selected or State.picked else nil
	if want ~= lastHeld then
		lastHeld = want
		send("hold", want)
	end
end

local function cycle(dir: number)
	local list = Hud.usableItems(State.phase(), player:GetAttributes())
	if #list == 0 then
		-- passive items can still be looked at
		local held = Hud.slots(player:GetAttributes())
		if #held > 0 then
			local i = table.find(held, State.picked or "") or 0
			State.picked = held[((i - 1 + dir) % #held) + 1]
		end
	else
		State.cycle(list, dir)
		State.picked = State.selected
	end
	SoundManager.sfx("Click")
	Hud.update()
	syncHeld()
end

local function selectItem(id: string?)
	if not id then
		return
	end
	State.picked = id
	local def = Items.Defs[id]
	if def and def.use and Items.usableIn(id, State.phase()) then
		State.selected = id
	end
	SoundManager.sfx("Click")
	Hud.update()
	syncHeld()
end

local function useItem(item: string?)
	local id = item or State.selected
	if id then
		send("use", id)
	end
end

-- one action handler for buttons, keys and gamepad
local function act(action: string, arg: any?)
	if State.inIntro then
		return
	end
	local who, phase = State.who(), State.phase()
	if action == "primary" then
		if phase ~= "Night" then
			return
		end
		if who == "Guest" then
			send("lantern")
		elseif who == "Phantom" then
			send("tag")
		elseif who == "Wisp" then
			send("flicker")
		end
	elseif action == "gadget" then
		if who == "Wisp" then
			send("slick")
		else
			send("gadget")
		end
	elseif action == "use" then
		useItem(arg)
	elseif action == "next" then
		cycle(1)
	elseif action == "prev" then
		cycle(-1)
	elseif action == "slot" then
		selectItem(Hud.slotItem(arg))
	elseif action == "select" then
		selectItem(arg)
	elseif action == "info" then
		Menus.toggle("Items")
	elseif action == "menu" then
		if type(arg) == "string" then
			Menus.open(arg)
		else
			Menus.toggle(if phase == "Lobby" then "Shop" else "Settings")
		end
	elseif action == "cell" then
		useItem("DryCell")
	elseif action == "lantern" then
		send("lantern")
	elseif action == "flicker" or action == "slick" or action == "tag" then
		send(action)
	end
end

Hud.onButton(function(action, item)
	SoundManager.sfx("Click")
	if action == "lantern" or action == "tag" or action == "flicker" or action == "slick" then
		send(action)
	else
		act(action, item)
	end
end)
Input.bind(act)

-- the Evidence Board's Vote prompt opens the vote panel
pcall(function()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "Vote" then
			Menus.open("Vote")
		end
	end)
end)

Notify.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local k = payload.kind
	if k == "toast" then
		State.toast = { text = tostring(payload.text), color = payload.color, at = os.clock() }
		if string.find(State.toast.text, "tampered - it trips", 1, true) then
			Guide.noteTamper()
		end
	elseif k == "sfx" then
		SoundManager.sfx(tostring(payload.cue))
	elseif k == "role" then
		State.role = payload.role
		State.mates = payload.mates or {}
		State.results = nil
		Hud.showRole(payload.role, payload.mates)
	elseif k == "channel" then
		State.channel = if payload.channel then payload else nil
	elseif k == "results" then
		State.results = payload
		State.channel = nil
	elseif k == "item" then
		Hud.showItem(payload.icon, tostring(payload.name), tostring(payload.kid or ""))
		Guide.noteItem()
		if payload.item and Items.Defs[payload.item] and not payload.full then
			State.picked = payload.item
			if Items.Defs[payload.item].use and State.selected == nil then
				State.selected = payload.item
			end
			syncHeld()
		end
	elseif k == "used" then
		local def = Items.Defs[payload.item]
		if def then
			State.toast = { text = (def.icon or "") .. " " .. def.name .. "!", color = def.color, at = os.clock() }
		end
	elseif k == "ink" then
		State.inkUntil = os.clock() + (tonumber(payload.seconds) or 3)
	elseif k == "night" then
		Hud.banner(string.format("NIGHT %d of %d", payload.no, payload.count), tostring(payload.name), if payload.nightKind == "finale" then "Gold" else "Brass", 3.5)
	elseif k == "dawn" then
		Hud.banner(if payload.winner == "Guests" then "DAWN! ☀️" else "STILL DARK... 🌙", tostring(payload.reason), if payload.winner == "Guests" then "TealNeon" else "MaskNeon", 6)
	elseif k == "badge" then
		Hud.banner("🏅 BADGE: " .. tostring(payload.name), tostring(payload.desc), "Gold", 4)
	elseif k == "daily" then
		Hud.banner(string.format("🎁 DAY %d LOGIN GIFT", payload.day), string.format("+%d Gear Tokens%s", payload.tokens, if payload.item then " + a new mask!" else ""), "Amber", 5)
	elseif k == "bought" then
		State.toast = { text = "Unlocked: " .. tostring(payload.name) .. "!", color = "TealNeon", at = os.clock() }
		if State.panel == "Shop" then
			Menus.open("Shop")
		end
	elseif k == "quest" then
		-- a daily/weekly quest just completed (QuestService.onMatchEnd)
		State.toast = { text = string.format("✔ %s  +%d ⚙", tostring(payload.text), tonumber(payload.tokens) or 0), color = "TealNeon", at = os.clock() }
	elseif k == "seasonTier" then
		-- season tier up (DataService.award): the cosmetic unlocks via Progression.owns
		Hud.banner(string.format("❄️ SEASON TIER %d!", tonumber(payload.tier) or 0), "Reward unlocked - check the Quests panel!", "Gold", 4)
	end
end)

local lastPhase = nil
local aimAccum, uiAccum, promptAccum = 0, 0, 0
local introChecked = false
local lastMusic, lastSfx = nil, nil
RunService.Heartbeat:Connect(function(dt)
	aimAccum += dt
	uiAccum += dt
	promptAccum += dt
	Intro.step(dt)
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
		if phase == "Day" and State.panel == "Vote" then
			Menus.close()
		elseif phase == "Night" and State.panel == "Vote" then
			Menus.close()
		end
	end
	-- first visit: the story intro, then the guided first match
	if not introChecked and player:GetAttribute("IntroSeen") ~= nil then
		introChecked = true
		if player:GetAttribute("IntroSeen") == false then
			playIntro(true)
		elseif player:GetAttribute("TutorialDone") == false then
			startTutorial()
		end
	end
	local m, s = player:GetAttribute("Set_Music"), player:GetAttribute("Set_Sfx")
	if m ~= lastMusic or s ~= lastSfx then
		lastMusic, lastSfx = m, s
		SoundManager.setEnabled(m ~= false, s ~= false)
	end
	if aimAccum >= 0.1 then
		aimAccum = 0
		if player:GetAttribute("LanternOn") or player:GetAttribute("PClass") == "Illuminator" then
			local cam = workspace.CurrentCamera
			if cam and State.who() == "Guest" and phase == "Night" then
				local v = cam.CFrame.LookVector
				Aim:FireServer(v.X, v.Y, v.Z)
			end
		end
	end
	if uiAccum >= 0.1 then
		uiAccum = 0
		Hud.update()
		Guide.update()
		syncHeld()
	end
	if promptAccum >= 0.3 then
		promptAccum = 0
		PromptFilter.refresh()
	end
end)
send("whoami")
