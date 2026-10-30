-- Escalation (pure data): the Rising Storm pass - every night is tenser than the last, the
-- finish of each night has a sprint, and the last surviving guests get a comeback edge.
-- Applied via workspace attributes (set by MatchService.beginDay) plus pure helpers in
-- Logic/Escalation, so every effect here is data-tuned, not code-tuned.
return {
	-- Per match-night (orderIdx 1..3; the last entry repeats if a match had more nights):
	--   drainFactor       lantern battery drains this much faster for everyone
	--   phantomSpeedBonus Phantom night speed +this many studs/s (additive, before beam slows)
	--   rebootBoost       grid reboot fills this much faster (multiplicative)
	Nights = {
		{ drainFactor = 1.0, phantomSpeedBonus = 0, rebootBoost = 1.0 },
		{ drainFactor = 1.15, phantomSpeedBonus = 0.5, rebootBoost = 1.0 },
		{ drainFactor = 1.3, phantomSpeedBonus = 1.0, rebootBoost = 1.15 },
	},
	-- Dawn Rush: once the reboot passes rebootAt, the grid surges and fills boost faster -
	-- every night ends in a sprint instead of a stall.
	Rush = { rebootAt = 0.8, boost = 1.25 },
	-- Last Stand: with this many guests still alive (and at least minAlive), survivors move
	-- speedBonus studs/s faster and their lanterns burn slower. Rubber-banding that creates
	-- comeback stories instead of foregone conclusions.
	LastStand = { aliveAtOrBelow = 2, minAlive = 1, speedBonus = 2, drainFactor = 0.85 },
}
