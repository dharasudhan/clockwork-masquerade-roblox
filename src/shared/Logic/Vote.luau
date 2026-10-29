-- Expose voting at the Evidence Board (pure). One vote per voter per Day (changeable until
-- nightfall). At nightfall the top candidate is exposed if they got at least `minVotes` and at
-- least `minShare` of the alive voters, and strictly more than the runner-up.
-- Approach compared with MIT round frameworks' map votes (tally dictionary, highest wins, ties
-- = no result); written from scratch.
local Vote = {}

function Vote.new()
	return { votes = {} } -- voterId -> targetId
end

function Vote.cast(v, voter: string, target: string, valid: { [string]: boolean }): (boolean, string?)
	if voter == target then
		return false, "self"
	end
	if not valid[target] then
		return false, "unknown"
	end
	v.votes[voter] = target
	return true
end

function Vote.tally(v)
	local counts, n = {}, 0
	for _, t in v.votes do
		counts[t] = (counts[t] or 0) + 1
		n += 1
	end
	return counts, n
end

-- Returns targetId or nil, plus the counts.
function Vote.result(v, aliveVoters: number, minVotes: number, minShare: number)
	local counts = Vote.tally(v)
	local best, bn, second = nil, 0, 0
	local ids = {}
	for id in counts do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local c = counts[id]
		if c > bn then
			second = bn
			best, bn = id, c
		elseif c > second then
			second = c
		end
	end
	if best == nil or bn < minVotes or bn <= second or bn < math.ceil(aliveVoters * minShare - 1e-9) then
		return nil, counts
	end
	return best, counts
end

function Vote.votersFor(v, target: string): { string }
	local out = {}
	for voter, t in v.votes do
		if t == target then
			table.insert(out, voter)
		end
	end
	table.sort(out)
	return out
end

-- A clue for a tampered breaker: the tamperer's ribbon plus one other ribbon, shuffled by `r`.
function Vote.clue(tampererRibbon: string, others: { string }, r: number): { string }
	if #others == 0 then
		return { tampererRibbon }
	end
	local other = others[math.clamp(math.floor(r * #others) + 1, 1, #others)]
	if r < 0.5 then
		return { tampererRibbon, other }
	end
	return { other, tampererRibbon }
end

return Vote
