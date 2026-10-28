return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Brain = t.load("Logic/BotBrain")
	local Cfg = t.load("Config/Bots")
	local G = t.load("Config/Gadgets")
	local N = t.load("Config/Nights")[1]
	local function me(o)
		local m = { id = "me", x = 0, z = 0, battery = 20, inv = { DryCell = 0, CopperWire = 0, GlowStick = 0 } }
		for k, v in o or {} do
			m[k] = v
		end
		return m
	end
	describe("Guest bot", function()
		it("day: walks to the nearest chest and opens it in range", function()
			local w = { phase = "Day", chests = { { id = "c1", x = 30, z = 0 }, { id = "c2", x = 10, z = 0 } }, breakers = {}, guests = {}, phantoms = {} }
			local d = Brain.guest(me(), w, Cfg, G, N)
			expect(d.action).to.equal("move")
			expect(d.x).to.equal(10)
			d = Brain.guest(me({ x = 7 }), w, Cfg, G, N)
			expect(d.action).to.equal("open")
			expect(d.id).to.equal("c2")
		end)
		it("night: shines the lantern at a nearby Phantom, runs when it is close", function()
			local w = { phase = "Night", phantoms = { { id = "p", x = 20, z = 0 } }, guests = { { id = "me", x = 0, z = 0 } }, breakers = {}, chests = {}, fleeSpots = { { x = 30, z = 0 }, { x = -30, z = 0 } } }
			local d = Brain.guest(me(), w, Cfg, G, N)
			expect(d.lantern).to.equal(true)
			expect(d.aimX).to.equal(20)
			w.phantoms[1].x = 8
			d = Brain.guest(me(), w, Cfg, G, N)
			expect(d.action).to.equal("move")
			expect(d.x).to.equal(-30)
		end)
		it("night: repairs a tampered breaker when safe; uses a dry-cell when low", function()
			local w = { phase = "Night", phantoms = {}, guests = {}, chests = {}, breakers = { { id = "A", x = 3, z = 0, tampered = true } } }
			local d = Brain.guest(me({ battery = 2, inv = { DryCell = 1 } }), w, Cfg, G, N)
			expect(d.action).to.equal("repair")
			expect(d.item).to.equal("DryCell")
		end)
		it("is level-aware: a chest one floor up counts as far", function()
			local w = { phase = "Day", chests = { { id = "up", x = 2, y = 23, z = 0 }, { id = "here", x = 30, y = 3, z = 0 } }, breakers = {}, guests = {}, phantoms = {} }
			local d = Brain.guest(me({ y = 3 }), w, Cfg, G, N)
			expect(d.x).to.equal(30)
		end)
		it("night items: smoke away when cornered, else decoy / boots; bell at a breaker", function()
			local w = { phase = "Night", phantoms = { { id = "p", x = 5, y = 3, z = 0 } }, guests = { { id = "me", x = 0, y = 3, z = 0 } }, breakers = {}, chests = {}, fleeSpots = { { x = -30, y = 3, z = 0 } } }
			local d = Brain.guest(me({ y = 3, inv = { SmokePellet = 1, ClockworkDecoy = 1 } }), w, Cfg, G, N)
			expect(d.item).to.equal("SmokePellet")
			expect(d.itemDir.x < 0).to.equal(true) -- away from the Phantom
			d = Brain.guest(me({ y = 3, inv = { ClockworkDecoy = 1 } }), w, Cfg, G, N)
			expect(d.item).to.equal("ClockworkDecoy")
			d = Brain.guest(me({ y = 3, inv = { SpringBoots = 1 } }), w, Cfg, G, N)
			expect(d.item).to.equal("SpringBoots")
			local w2 = { phase = "Night", phantoms = {}, guests = {}, chests = {}, breakers = { { id = "A", x = 2, y = 3, z = 0, tampered = true } } }
			d = Brain.guest(me({ y = 3, inv = { TripwireBell = 1 } }), w2, Cfg, G, N)
			expect(d.action).to.equal("repair")
			expect(d.item).to.equal("TripwireBell")
			d = Brain.guest(me({ y = 3, inv = { PocketWatch = 1 }, itemReady = { PocketWatch = false } }), w2, Cfg, G, N)
			expect(d.item).to.equal(nil) -- on cooldown
		end)
	end)
	describe("Phantom bot", function()
		it("day: tampers an unwatched breaker, skips a watched one", function()
			local w = { phase = "Day", tampersLeft = 1, guests = { { id = "g", x = 100, z = 0 } }, chests = {}, breakers = { { id = "A", x = 2, z = 0, tampered = false }, { id = "B", x = 100, z = 2, tampered = false } } }
			expect(Brain.phantom(me(), w, Cfg, G, N).action).to.equal("tamper")
			w.guests[1].x = 4
			local d = Brain.phantom(me(), w, Cfg, G, N)
			expect(d.action).to.equal("move")
			expect(d.x).to.equal(100)
			-- every breaker watched -> searches a chest to blend in
			w.guests = { { id = "g", x = 4, z = 0 }, { id = "h", x = 100, z = 4 } }
			w.chests = { { id = "c", x = 3, z = 3 } }
			expect(Brain.phantom(me(), w, Cfg, G, N).action).to.equal("open")
			-- late in the day it tampers anyway
			w.timeLeft = Cfg.BoldSeconds - 1
			expect(Brain.phantom(me(), w, Cfg, G, N).action).to.equal("tamper")
		end)
		it("night: hunts the isolated guest over the grouped one, tags in range", function()
			local w = { phase = "Night", guests = {
				{ id = "g1", x = 20, z = 0 }, { id = "g2", x = 22, z = 0 }, { id = "g3", x = 21, z = 2 },
				{ id = "lone", x = -30, z = 0 },
			}, phantoms = {}, chests = {}, breakers = {} }
			local d = Brain.phantom(me(), w, Cfg, G, N)
			expect(d.x).to.equal(-30)
			w.guests = { { id = "lone", x = 3, z = 0 } }
			d = Brain.phantom(me(), w, Cfg, G, N)
			expect(d.action).to.equal("tag")
			expect(d.id).to.equal("lone")
		end)
		it("night: a ticking decoy nearby lures it; tags the decoy in range", function()
			local w = { phase = "Night", guests = { { id = "g", x = 20, z = 0 } }, decoys = { { id = "D1", x = -25, z = 0 } }, phantoms = {}, chests = {}, breakers = {} }
			local d = Brain.phantom(me(), w, Cfg, G, N)
			expect(d.x).to.equal(-25)
			w.decoys[1].x = 3
			d = Brain.phantom(me(), w, Cfg, G, N)
			expect(d.action).to.equal("tag")
			expect(d.id).to.equal("D1")
		end)
	end)
	describe("Wisp bot", function()
		it("drops a slick near a guest, flickers a room with guests", function()
			local w = { guests = { { id = "g", x = 5, z = 0 } }, guestsInRoom = 1 }
			expect(Brain.wisp(me({ slickReady = true }), w, Cfg, G).action).to.equal("slick")
			expect(Brain.wisp(me({ flickerReady = true }), w, Cfg, G).action).to.equal("flicker")
			expect(Brain.wisp(me(), w, Cfg, G).action).to.equal("move")
		end)
	end)
end
