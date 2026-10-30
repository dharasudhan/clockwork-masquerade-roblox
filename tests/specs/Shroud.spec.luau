return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Shroud = t.load("Logic/Shroud")
	local Style = t.load("Config/Style")

	local R15 = { head = { 1.2, 1.2, 1.2 }, torso = { 2, 1.6, 1 }, drop = 3.2, arm = { 1, 1.2, 1 }, r6 = false }
	local R6 = { head = { 2, 1, 1 }, torso = { 2, 2, 1 }, drop = 3, arm = { 1, 2, 1 }, r6 = true }
	local RTHRO = { head = { 1.5, 1.5, 1.5 }, torso = { 2.4, 2.1, 1.3 }, drop = 4.6, arm = { 1.1, 1.6, 1.1 }, r6 = false }

	describe("Shroud.classify", function()
		it("stashes clothing, accessories, layered clothing, body colours, R6 meshes, PBR skins", function()
			for _, cls in { "Shirt", "Pants", "ShirtGraphic", "Accessory", "Accoutrement", "Hat", "BodyColors", "CharacterMesh", "SurfaceAppearance", "WrapLayer" } do
				expect(Shroud.classify(cls, "x", false)).to.equal("stash")
			end
		end)
		it("hides face decals and the bot fallback hat, disables avatar trails", function()
			expect(Shroud.classify("Decal", "face", false)).to.equal("hide")
			expect(Shroud.classify("Texture", "skin", false)).to.equal("hide")
			expect(Shroud.classify("Part", "Hat", true)).to.equal("hide")
			expect(Shroud.classify("Part", "HatBrim", true)).to.equal("hide")
			expect(Shroud.classify("Trail", "Aura", false)).to.equal("disable")
			expect(Shroud.classify("Sparkles", "Sparkles", false)).to.equal("disable")
		end)
		it("recolours R15 and R6 body parts and uniforms the lantern lamp", function()
			for _, n in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightHand", "LeftFoot", "Torso", "Left Arm", "Right Leg" } do
				expect(Shroud.classify("MeshPart", n, true)).to.equal("body")
			end
			expect(Shroud.classify("Part", "LanternLamp", true)).to.equal("lamp")
		end)
		it("never touches the root, the Phantom mask/glow, held items, the cloak or unknown parts", function()
			for _, n in { "HumanoidRootPart", "PhantomMask", "PhantomGlow", "PhantomShroud", "HeldItem", "WispOrb", "MasqueradeMask", "Ribbon" } do
				expect(Shroud.classify("Part", n, true)).to.equal("keep")
			end
			expect(Shroud.classify("Part", "CarryKeyProp", true)).to.equal("keep")
			expect(Shroud.classify("Humanoid", "Humanoid", false)).to.equal("keep")
			expect(Shroud.classify("Script", "Animate", false)).to.equal("keep")
			expect(Shroud.classify("Attachment", "HatAttachment", false)).to.equal("keep")
		end)
		it("skips anything inside something already stashed or kept", function()
			expect(Shroud.classify("Part", "Handle", true, true)).to.equal("keep")
			expect(Shroud.classify("Decal", "face", false, true)).to.equal("keep")
		end)
	end)

	describe("Shroud ledger (stash / restore)", function()
		local function fakeChar()
			local model = { name = "char" }
			local shirt = { name = "Shirt", Parent = model }
			local hat = { name = "Hat", Parent = model }
			local head = { name = "Head", Parent = model, Color = "skin", Transparency = 0 }
			local face = { name = "face", Parent = head, Transparency = 0 }
			return model, shirt, hat, head, face
		end
		local function applyTo(ledger, stash, shirt, hat, head, face)
			for _, inst in { shirt, hat } do
				Shroud.rememberParent(ledger, inst, inst.Parent)
				inst.Parent = stash
			end
			Shroud.rememberProp(ledger, head, "Color", head.Color)
			head.Color = "shroud"
			Shroud.rememberProp(ledger, face, "Transparency", face.Transparency)
			face.Transparency = 1
		end
		local function restore(ledger)
			for _, e in Shroud.undo(ledger) do
				if e.kind == "parent" then
					e.target.Parent = e.old
				else
					e.target[e.prop] = e.old
				end
			end
		end
		it("restores parents and properties exactly", function()
			local model, shirt, hat, head, face = fakeChar()
			local ledger, stash = Shroud.newLedger(), { name = "stash" }
			applyTo(ledger, stash, shirt, hat, head, face)
			expect(shirt.Parent).to.equal(stash)
			expect(head.Color).to.equal("shroud")
			expect(Shroud.size(ledger)).to.equal(4)
			restore(ledger)
			expect(shirt.Parent).to.equal(model)
			expect(hat.Parent).to.equal(model)
			expect(head.Color).to.equal("skin")
			expect(face.Transparency).to.equal(0)
			expect(Shroud.size(ledger)).to.equal(0)
		end)
		it("applying twice keeps the ORIGINAL values (never records the shroud as the original)", function()
			local model, shirt, hat, head, face = fakeChar()
			local ledger, stash = Shroud.newLedger(), { name = "stash" }
			applyTo(ledger, stash, shirt, hat, head, face)
			applyTo(ledger, stash, shirt, hat, head, face) -- e.g. a second nightfall call / re-dress
			expect(Shroud.size(ledger)).to.equal(4)
			restore(ledger)
			expect(shirt.Parent).to.equal(model)
			expect(head.Color).to.equal("skin")
			expect(face.Transparency).to.equal(0)
		end)
		it("undo runs newest first and empties the ledger (restoring twice is a no-op)", function()
			local ledger = Shroud.newLedger()
			local a, b = {}, {}
			Shroud.rememberProp(ledger, a, "Color", 1)
			Shroud.rememberProp(ledger, b, "Color", 2)
			local out = Shroud.undo(ledger)
			expect(out[1].target).to.equal(b)
			expect(out[2].target).to.equal(a)
			expect(#Shroud.undo(ledger)).to.equal(0)
		end)
	end)

	describe("Shroud.layout (uniform cloak)", function()
		it("same parts, colours and materials for R15, R6 and rthro rigs", function()
			local s15, s6, sr = Shroud.signature(Shroud.layout(R15)), Shroud.signature(Shroud.layout(R6)), Shroud.signature(Shroud.layout(RTHRO))
			expect(s15).to.equal(s6)
			expect(s15).to.equal(sr)
		end)
		it("full body: hood, peak, mantle, skirt, 6 tatters, 2 sleeves, clasp, 2 eyes, within the part budget", function()
			local specs = Shroud.layout(R15)
			expect(#specs).to.equal(15)
			expect(#specs <= Shroud.MaxParts).to.equal(true)
			local names = {}
			for _, sp in specs do
				names[sp.name] = sp
			end
			for _, n in { "Hood", "HoodPeak", "Mantle", "Skirt", "Clasp", "EyeL", "EyeR", "SleeveL", "SleeveR", "TatterFL", "TatterBR", "TatterL" } do
				expect(names[n] ~= nil).to.equal(true)
			end
			expect(names.EyeL.material).to.equal("Neon")
			expect(names.EyeL.color).to.equal(Shroud.Eye)
		end)
		it("the skirt reaches from the waist to just above the floor on every rig", function()
			for _, d in { R15, R6, RTHRO } do
				for _, sp in Shroud.layout(d) do
					if sp.name == "Skirt" then
						local bottom = -sp.pos[2] + sp.size[2] / 2
						local top = -sp.pos[2] - sp.size[2] / 2
						expect(bottom).to.be.near(d.drop - 0.25, 1e-6)
						expect(top <= d.torso[2] * 0.5).to.equal(true)
					end
				end
			end
		end)
		it("the hood covers the face and the eyes sit in front of hood and Phantom mask", function()
			for _, d in { R15, R6, RTHRO } do
				local hood, eye
				for _, sp in Shroud.layout(d) do
					if sp.name == "Hood" then
						hood = sp
					elseif sp.name == "EyeL" then
						eye = sp
					end
				end
				local front = hood.pos[3] - hood.size[1] / 2 -- -Z is the front
				expect(front < -d.head[3] / 2).to.equal(true)
				expect(eye.pos[3] <= front - 0.05).to.equal(true)
				expect(eye.pos[3] <= Shroud.EyeZ).to.equal(true)
			end
		end)
		it("no sleeves when the rig has no arms (still a valid cloak)", function()
			local specs = Shroud.layout({ head = { 1, 1, 1 }, torso = { 2, 1.6, 1 }, drop = 3, r6 = false })
			expect(#specs).to.equal(13)
		end)
		it("every palette key the cloak uses exists", function()
			for _, sp in Shroud.layout(R15) do
				expect(Style.Palette[sp.color] ~= nil).to.equal(true)
			end
			expect(Style.Palette[Shroud.LampColor] ~= nil).to.equal(true)
		end)
	end)
end
