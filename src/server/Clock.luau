-- One clock for the whole server. Real servers use workspace:GetServerTimeNow() (the same
-- clock clients read, so *At attributes can be shown as countdowns). Tests swap in a fake.
local Clock = {}

local fake: number? = nil

function Clock.now(): number
	if fake then
		return fake
	end
	return workspace:GetServerTimeNow()
end

-- wall-clock seconds (daily rewards); tests can shift it by whole days
local wallShift = 0
function Clock.wall(): number
	return os.time() + wallShift
end
function Clock.shiftWall(seconds: number)
	wallShift += seconds
end

function Clock.setFake(t: number?)
	fake = t
end

function Clock.advance(dt: number)
	fake = (fake or 0) + dt
end

return Clock
