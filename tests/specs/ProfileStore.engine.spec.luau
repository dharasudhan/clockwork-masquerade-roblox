-- Engine-only spec (skipped under Lune): ProfileStore's mock store in a real Roblox server
-- (Open Cloud Luau Execution) saves and reads back the Clockwork Masquerade template.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ServerScriptService = game:GetService("ServerScriptService")
	local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
	local Template = t.load("Config/DataTemplate")
	local SaveData = t.load("Logic/SaveData")

	describe("ProfileStore (mock)", function()
		it("starts a session, saves wins + Gear Tokens and reads them back", function()
			local store = ProfileStore.New("ClockworkMasquerade_Test_" .. tostring(os.time()), Template)
			local key = "Test_" .. tostring(math.random(1, 1e9))
			local profile = store.Mock:StartSessionAsync(key)
			expect(profile).to.be.ok()
			profile:Reconcile()
			expect(SaveData.sanitize(profile.Data, Template)).to.equal(0)
			profile.Data.GearTokens = 37
			profile.Data.Wins.Guest = 2
			profile.Data.Played = 3
			profile:EndSession()
			task.wait(1)
			local view = store.Mock:GetAsync(key)
			expect(view).to.be.ok()
			expect(view.Data.GearTokens).to.equal(37)
			expect(view.Data.Wins.Guest).to.equal(2)
			expect(view.Data.Wins.Phantom).to.equal(0)
		end)
	end)
end
