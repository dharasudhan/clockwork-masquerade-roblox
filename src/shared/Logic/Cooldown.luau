-- Cooldowns + Wisp ability limits (pure).
local Cooldown = {}

function Cooldown.ready(lastAt: number?, cooldown: number, now: number): boolean
	return lastAt == nil or now - lastAt >= cooldown
end

function Cooldown.readyAt(lastAt: number?, cooldown: number): number
	return if lastAt == nil then 0 else lastAt + cooldown
end

-- Oil slick: cooldown ready and fewer than maxAlive of this Wisp's slicks still on the floor.
function Cooldown.canSlick(alive: number, lastAt: number?, now: number, cfg): boolean
	return alive < cfg.slickMaxAlive and Cooldown.ready(lastAt, cfg.slickCooldown, now)
end

return Cooldown
