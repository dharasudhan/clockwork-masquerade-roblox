-- Win check (pure), v1.0 three-night match.
--   * every guest tagged                       -> Phantoms win the night (grid nights) or the
--                                                 match (finale / last night)
--   * every Phantom left the server            -> Guests, match over
--   grid nights (1-2):
--   * reboot reaches 100% with a guest untagged -> Guests win the NIGHT ("dawn")
--   * the night timer runs out below 100%       -> Phantoms win the NIGHT ("dark")
--     (the match goes on to the next night unless this night is the last one)
--   finale (3):
--   * ring progress reaches the target          -> Guests, match over
--   * Showdown timer out before 3 keys          -> Phantoms, match over
--   * Overdrive timer out before the ring       -> Phantoms, match over
-- Returns { winner, reason, final } or nil.
local Outcome = {}

export type State = {
	phase: string,
	kind: string?, -- "grid" (default) | "finale"
	stage: string?, -- finale: "Showdown" | "Overdrive"
	last: boolean?, -- true when this is the match's last night (default true)
	guestsTotal: number,
	guestsAlive: number,
	phantoms: number,
	reboot: number,
	ring: number?, -- finale ring progress (seconds)
	ringNeed: number?,
	timeLeft: number,
}

function Outcome.evaluate(s: State): { winner: string, reason: string, final: boolean }?
	if s.phase ~= "Day" and s.phase ~= "Night" then
		return nil
	end
	local last = s.last ~= false
	if s.guestsAlive <= 0 then
		-- balance pass 2: a wipe on night 1-2 loses that night, not the whole match
		return { winner = "Phantoms", reason = "All guests were tagged", final = last or s.kind == "finale" }
	end
	if s.phantoms <= 0 then
		return { winner = "Guests", reason = "The Phantoms fled", final = true }
	end
	if s.phase ~= "Night" then
		return nil
	end
	if s.kind == "finale" then
		if s.stage == "Overdrive" and (s.ring or 0) >= (s.ringNeed or math.huge) then
			return { winner = "Guests", reason = "Dawn Reboot complete - sunrise!", final = true }
		end
		if s.timeLeft <= 0 then
			if s.stage == "Overdrive" then
				return { winner = "Phantoms", reason = "The console never powered up", final = true }
			end
			return { winner = "Phantoms", reason = "The keys were never brought to the console", final = true }
		end
		return nil
	end
	if s.reboot >= 100 then
		return { winner = "Guests", reason = "Grid rebooted - dawn!", final = last }
	end
	if s.timeLeft <= 0 then
		return { winner = "Phantoms", reason = "The manor stayed dark", final = last }
	end
	return nil
end

return Outcome
