return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Cooldown = t.load("Logic/Cooldown")
	local Channel = t.load("Logic/Channel")
	local Rewards = t.load("Logic/Rewards")
	local SaveData = t.load("Logic/SaveData")
	local RateLimiter = t.load("Logic/RateLimiter")
	local G = t.load("Config/Gadgets")
	local Template = t.load("Config/DataTemplate")
	describe("Cooldowns + Wisp limits", function()
		it("M1.1: flicker 30 s, slick 45 s with max 2 alive, slicks outlive 2 cooldowns", function()
			expect(G.Wisp.flickerCooldown).to.equal(30)
			expect(G.Wisp.slickCooldown).to.equal(45)
			expect(G.Wisp.slickMaxAlive).to.equal(2)
			expect(G.Wisp.slickLifetime > 2 * G.Wisp.slickCooldown).to.equal(true)
			expect(Cooldown.ready(nil, 20, 0)).to.equal(true)
			expect(Cooldown.ready(10, 20, 29)).to.equal(false)
			expect(Cooldown.ready(10, 20, 30)).to.equal(true)
			expect(Cooldown.canSlick(2, nil, 100, G.Wisp)).to.equal(false)
			expect(Cooldown.canSlick(1, 0, 44, G.Wisp)).to.equal(false)
			expect(Cooldown.canSlick(1, 0, 45, G.Wisp)).to.equal(true)
		end)
	end)
	describe("Channels", function()
		it("tamper channel needs 4 stationary seconds, moving cancels", function()
			local ch = Channel.new("p", "A", 0, 0, 0)
			expect(Channel.check(ch, 0.5, 0, 2, 0, 1.5, 7)).to.equal("running")
			expect(Channel.check(ch, 2, 0, 2, 0, 1.5, 7)).to.equal("cancelled")
			expect(Channel.check(ch, 0, 0, 20, 0, 1.5, 7)).to.equal("cancelled")
			local done = false
			for _ = 1, 40 do
				done = Channel.advance(ch, 0.1, 4)
			end
			expect(done).to.equal(true)
		end)
	end)
	describe("Rewards + saves", function()
		it("Gear Tokens: base + win + actions, capped", function()
			local R = G.Rewards
			expect(Rewards.tokens({}, false, R)).to.equal(R.played)
			expect(Rewards.tokens({ chests = 2, repairs = 1 }, true, R)).to.equal(R.played + R.win + 2 * R.perChest + R.perRepair)
			expect(Rewards.tokens({ nightsWon = 2, keys = 1, pages = 1, exposes = 1 }, false, R)).to.equal(R.played + 2 * R.nightWon + R.key + R.page + R.expose)
			expect(R.cap).to.equal(90)
			expect(Rewards.tokens({ tags = 100 }, true, R)).to.equal(R.cap)
			-- 2x Gear Tokens pass doubles after the cap; XP stays the base amount
			local t2, xp = Rewards.tokens({ tags = 100 }, true, R, 2)
			expect(t2).to.equal(2 * R.cap)
			expect(xp).to.equal(R.cap)
		end)
		it("sanitises corrupt saves to safe defaults", function()
			local d = { GearTokens = -5, Wins = { Guest = 0 / 0, Phantom = 2.7 }, Played = "x", Extra = 1 }
			local fixes = SaveData.sanitize(d, Template)
			expect(fixes > 0).to.equal(true)
			expect(d.GearTokens).to.equal(0)
			expect(d.Wins.Guest).to.equal(0)
			expect(d.Wins.Phantom).to.equal(2)
			expect(d.Played).to.equal(0)
			expect(d.Version).to.equal(2)
			expect(d.Class).to.equal("Mechanist")
			expect(d.Equipped.Mask).to.equal("mask_brass")
			expect(d.IntroSeen).to.equal(false)
			expect(d.Settings.Music).to.equal(true)
			expect(d.Extra).to.equal(1)
			local fresh = SaveData.clone(Template)
			expect(SaveData.sanitize(fresh, Template)).to.equal(0)
		end)
		it("rate limiter allows a burst then refills", function()
			local rl = RateLimiter.new(3, 1)
			expect(rl:allow("k", 0)).to.equal(true)
			expect(rl:allow("k", 0)).to.equal(true)
			expect(rl:allow("k", 0)).to.equal(true)
			expect(rl:allow("k", 0)).to.equal(false)
			expect(rl:allow("k", 1.1)).to.equal(true)
		end)
	end)
	describe("Config sanity", function()
		it("v1.0 numbers: 3 nights, 6 breakers in the manor, 5 per grid night, 2 tampers, finale keys", function()
			local M = t.load("Config/Match")
			local Nights = t.load("Config/Nights")
			expect(M.LobbySeconds).to.equal(30)
			expect(M.MinPlayers).to.equal(6)
			expect(M.MaxPlayers).to.equal(10)
			expect(#M.NightOrder).to.equal(3)
			expect(Nights[1].kind).to.equal("grid")
			expect(Nights[2].kind).to.equal("grid")
			expect(Nights[3].kind).to.equal("finale")
			for i = 1, 2 do
				local N = Nights[i]
				expect(N.tamperSeconds).to.equal(4)
				expect(N.maxTampers).to.equal(2)
				expect(#N.breakers).to.equal(5)
				expect(N.rebootFullSeconds < N.nightSeconds).to.equal(true)
			end
			expect(Nights[2].archives.pages).to.equal(3)
			expect(Nights[2].phaseGlide.distance).to.equal(10)
			expect(Nights.nightLength(Nights[3])).to.equal(Nights[3].showdownSeconds + Nights[3].overdriveSeconds)
			local Bots = t.load("Config/Bots")
			expect(Bots.BoldSeconds).to.equal(40)
			local Manor = t.load("Config/Manor")
			expect(#Manor.Breakers).to.equal(6)
			expect(#Manor.Keys).to.equal(3)
			expect(#Manor.Cabinets).to.equal(8)
			local ids = {}
			for _, b in Manor.Breakers do
				ids[b.id] = true
			end
			for i = 1, 2 do
				for _, id in Nights[i].breakers do
					expect(ids[id]).to.equal(true)
				end
			end
		end)
		it("monetization is cosmetic-only and DRAFT: every id is a 0 placeholder, cosmetics grant no stats", function()
			local Mon = t.load("Config/Monetization")
			local C = t.load("Config/Cosmetics")
			for _, group in { Mon.Passes, Mon.Products } do
				for _, p in group do
					expect(p.id).to.equal(0)
					expect(p.priceDraft > 0).to.equal(true)
					for _, g in p.grants or {} do
						expect(C.byId(g) ~= nil).to.equal(true)
					end
				end
			end
			for _, c in C.Items do
				for k in c do
					expect(k == "speed" or k == "range" or k == "cooldown" or k == "power").to.equal(false)
				end
			end
		end)
		it("audio cues have ids, names and volumes", function()
			local A = t.load("Config/Audio")
			for _, group in { A.Music, A.Sfx } do
				for _, c in group do
					expect(type(c.id)).to.equal("number")
					expect(c.volume > 0 and c.volume <= 1).to.equal(true)
				end
			end
		end)
	end)
end
