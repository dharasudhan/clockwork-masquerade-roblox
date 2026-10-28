-- Win check (pure). M1 rules (Night 1 only):
--   * every guest tagged                         -> Phantoms ("All guests were tagged")
--   * every Phantom left the server              -> Guests   ("The Phantoms fled")
--   * reboot reaches 100% with a guest untagged  -> Guests   ("Grid rebooted - dawn!")
--   * the night timer runs out below 100%        -> Phantoms ("The manor stayed dark")
local Outcome = {}

export type State = {
	phase: string,
	guestsTotal: number,
	guestsAlive: number,
	phantoms: number,
	reboot: number,
	timeLeft: number,
}

function Outcome.evaluate(s: State): { winner: string, reason: string }?
	if s.phase ~= "Day" and s.phase ~= "Night" then
		return nil
	end
	if s.guestsAlive <= 0 then
		return { winner = "Phantoms", reason = "All guests were tagged" }
	end
	if s.phantoms <= 0 then
		return { winner = "Guests", reason = "The Phantoms fled" }
	end
	if s.phase == "Night" then
		if s.reboot >= 100 then
			return { winner = "Guests", reason = "Grid rebooted - dawn!" }
		end
		if s.timeLeft <= 0 then
			return { winner = "Phantoms", reason = "The manor stayed dark" }
		end
	end
	return nil
end

return Outcome
