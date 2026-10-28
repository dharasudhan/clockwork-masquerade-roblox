--!strict
-- Token-bucket rate limiter for RemoteEvents. Pure; caller passes `now`.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		burst: number,
		refill: number,
		buckets: { [any]: { tokens: number, at: number } },
	},
	RateLimiter
))

function RateLimiter.new(burst: number, refillPerSec: number): RateLimiter
	return setmetatable({ burst = burst, refill = refillPerSec, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any, now: number): boolean
	local b = self.buckets[key]
	if b == nil then
		b = { tokens = self.burst, at = now }
		self.buckets[key] = b
	else
		local elapsed = math.max(now - b.at, 0)
		b.tokens = math.min(self.burst, b.tokens + elapsed * self.refill)
		b.at = now
	end
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
