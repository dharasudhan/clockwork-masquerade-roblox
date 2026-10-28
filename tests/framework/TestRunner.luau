--!strict
-- Minimal TestEZ-style test runner that works both under Lune and inside Roblox.
-- API modelled on TestEZ (Roblox/testez, Apache-2.0): describe / it / expect(x).to.equal(y),
-- .to.be.near(y, eps), .to.be.ok(), .never, .to.throw(). Written from scratch, no TestEZ code copied.
--
-- A spec module returns `function(t)` where t = { describe, it, expect, beforeEach, load }.
-- `load(path)` resolves a shared module such as "Logic/Inventory" on the current platform.

local TestRunner = {}

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
TestRunner.deepEqual = deepEqual

local function show(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	elseif type(v) == "table" then
		local parts = {}
		local n = 0
		for k, x in v do
			n += 1
			if n > 8 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. show(x))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function makeExpect()
	return function(actual: any)
		local negate = false
		local api: any = {}

		local function check(pass: boolean, msg: string)
			if negate then
				pass = not pass
				msg = "NOT " .. msg
			end
			if not pass then
				error(msg, 3)
			end
			return api
		end

		local be: any = {}
		function be.ok()
			return check(actual ~= nil and actual ~= false, "expected " .. show(actual) .. " to be ok")
		end
		function be.near(expected: number, eps: number?)
			local e = eps or 1e-7
			return check(
				type(actual) == "number" and math.abs(actual - expected) <= e,
				"expected " .. show(actual) .. " to be near " .. show(expected) .. " (+/-" .. e .. ")"
			)
		end
		function be.a(typeName: string)
			return check(typeof(actual) == typeName, "expected " .. show(actual) .. " to be a " .. typeName)
		end
		function be.greaterThan(n: number)
			return check(
				type(actual) == "number" and actual > n,
				"expected " .. show(actual) .. " > " .. show(n)
			)
		end
		function be.lessThan(n: number)
			return check(
				type(actual) == "number" and actual < n,
				"expected " .. show(actual) .. " < " .. show(n)
			)
		end
		be.an = be.a

		local to: any = { be = be }
		function to.equal(expected: any)
			return check(actual == expected, "expected " .. show(actual) .. " to equal " .. show(expected))
		end
		function to.deepEqual(expected: any)
			return check(
				deepEqual(actual, expected),
				"expected " .. show(actual) .. " to deep-equal " .. show(expected)
			)
		end
		function to.throw(substring: string?)
			local ok, err = pcall(actual)
			local pass = not ok
				and (substring == nil or string.find(tostring(err), substring, 1, true) ~= nil)
			return check(
				pass,
				"expected function to throw" .. (if substring then " '" .. substring .. "'" else "")
			)
		end

		api.to = to
		local never: any = {}
		setmetatable(never, {
			__index = function(_, key)
				negate = true
				return api[key]
			end,
		})
		api.never = never
		return api
	end
end

export type Result = {
	passed: number,
	failed: number,
	skipped: number,
	failures: { { name: string, err: string } },
	lines: { string },
}

-- specs: array of { name = string, fn = function(t) }
function TestRunner.run(
	specs: { { name: string, fn: any } },
	load: (string) -> any,
	output: ((string) -> ())?
): Result
	local out = output or print
	local result: Result = { passed = 0, failed = 0, skipped = 0, failures = {}, lines = {} }
	local function log(s: string)
		table.insert(result.lines, s)
		out(s)
	end

	for _, spec in specs do
		-- collect tree
		type Node = { name: string, children: { any }, tests: { any }, beforeEach: { any } }
		local root: Node = { name = spec.name, children = {}, tests = {}, beforeEach = {} }
		local stack = { root }
		local function current(): Node
			return stack[#stack]
		end
		local t = {
			expect = makeExpect(),
			load = load,
			describe = function(name: string, body: () -> ())
				local node: Node = { name = name, children = {}, tests = {}, beforeEach = {} }
				table.insert(current().children, node)
				table.insert(stack, node)
				body()
				table.remove(stack)
			end,
			it = function(name: string, body: () -> ())
				table.insert(current().tests, { name = name, body = body })
			end,
			itSKIP = function(name: string)
				table.insert(current().tests, { name = name, skip = true })
			end,
			beforeEach = function(fn: () -> ())
				table.insert(current().beforeEach, fn)
			end,
		}

		local okCollect, collectErr = pcall(spec.fn, t)
		if not okCollect then
			result.failed += 1
			table.insert(result.failures, { name = spec.name .. " (load)", err = tostring(collectErr) })
			log("[FAIL] " .. spec.name .. " failed to load: " .. tostring(collectErr))
			continue
		end

		local function runNode(node: Node, prefix: string, hooks: { any })
			local allHooks = table.clone(hooks)
			for _, h in node.beforeEach do
				table.insert(allHooks, h)
			end
			for _, test in node.tests do
				local full = prefix .. " > " .. test.name
				if test.skip then
					result.skipped += 1
					log("[SKIP] " .. full)
					continue
				end
				local ok, err = pcall(function()
					for _, h in allHooks do
						h()
					end
					test.body()
				end)
				if ok then
					result.passed += 1
					log("[PASS] " .. full)
				else
					result.failed += 1
					table.insert(result.failures, { name = full, err = tostring(err) })
					log("[FAIL] " .. full .. "\n       " .. tostring(err))
				end
			end
			for _, child in node.children do
				runNode(child, prefix .. " > " .. child.name, allHooks)
			end
		end
		runNode(root, spec.name, {})
	end

	log(
		string.format(
			"\nTest summary: %d passed, %d failed, %d skipped",
			result.passed,
			result.failed,
			result.skipped
		)
	)
	log(if result.failed == 0 then "RESULT: PASS" else "RESULT: FAIL")
	return result
end

return TestRunner
