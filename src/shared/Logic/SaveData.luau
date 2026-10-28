-- Save sanitising (pure): every key of the template exists with the template's type; numbers
-- are finite, whole and >= 0. Unknown keys are kept (forward compatible). Returns fixes made.
local SaveData = {}

local function clone(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in v do
		c[k] = clone(x)
	end
	return c
end

local function fix(data, template): number
	local fixes = 0
	for k, def in template do
		local v = data[k]
		if type(def) == "table" then
			if type(v) ~= "table" then
				data[k] = clone(def)
				fixes += 1
			else
				fixes += fix(v, def)
			end
		elseif type(def) == "number" then
			if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
				data[k] = def
				fixes += 1
			elseif v < 0 or v ~= math.floor(v) then
				data[k] = math.max(0, math.floor(v))
				fixes += 1
			end
		elseif type(v) ~= type(def) then
			data[k] = def
			fixes += 1
		end
	end
	return fixes
end

function SaveData.sanitize(data, template): number
	return fix(data, template)
end

SaveData.clone = clone

return SaveData
