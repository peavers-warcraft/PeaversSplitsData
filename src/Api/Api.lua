local _, addonTable = ...

-- Create the global addon table
_G["PeaversSplitsData"] = _G["PeaversSplitsData"] or {}
local publicAPI = _G["PeaversSplitsData"]

-- Create the API namespace
publicAPI.API = publicAPI.API or {}
local API = publicAPI.API

--------------------------------------------------------------------------------
-- Lookup guards
--
-- Every argument is type-checked and every level of the lookup is guarded, so a
-- missing dungeon, level or boss yields nil rather than an error. Callers are
-- expected to query optimistically straight out of CHALLENGE_MODE_START and
-- ENCOUNTER_END, where the alternative is three nested `if type(...)` blocks at
-- every call site.
--------------------------------------------------------------------------------

---@param mapChallengeModeID number
---@return table|nil dungeon
local function getDungeon(mapChallengeModeID)
	if type(mapChallengeModeID) ~= "number" then
		return nil
	end

	local data = addonTable.SplitsData
	if type(data) ~= "table" or type(data.dungeons) ~= "table" then
		return nil
	end

	local dungeon = data.dungeons[mapChallengeModeID]
	if type(dungeon) ~= "table" then
		return nil
	end

	return dungeon
end

---@param mapChallengeModeID number
---@param keystoneLevel number
---@return table|nil bosses
local function getLevel(mapChallengeModeID, keystoneLevel)
	if type(keystoneLevel) ~= "number" then
		return nil
	end

	local dungeon = getDungeon(mapChallengeModeID)
	if not dungeon or type(dungeon.levels) ~= "table" then
		return nil
	end

	local bosses = dungeon.levels[keystoneLevel]
	if type(bosses) ~= "table" then
		return nil
	end

	return bosses
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---Returns the benchmark for one boss, at one exact keystone level, in one
---dungeon (see src\Data\Splits.lua).
---Shape: { order = 0, name = "Kystia Manaheart", split = 465.9, fast = 411.6,
---slow = 540.0, runs = 54 }. `split` is the pool's MEDIAN time in SECONDS from
---the start of the run to that boss dying; `fast` and `slow` are its p25 and
---p75, which together bracket the middle half and are what say whether a given
---delta means anything at all. `runs` is the sample the figures rest on, and is
---per boss rather than per level: a depleted run that ended at the third boss
---counts toward the first two and not the last.
---
---**The level is exact and is never approximated.** Enemy health scales per
---keystone level, so a +19 is genuinely slower than a +10 for reasons that are
---not the group's doing. A level with no entry means no pool at that level
---cleared the sample floor - it does NOT mean the neighbouring level will do.
---Consumers must say so rather than reaching sideways; see GetLevels for what
---to say instead.
---
---Returns nil on any miss and never errors, so callers can query straight out
---of ENCOUNTER_END. The table is shared, not copied - treat it as read-only.
---@param mapChallengeModeID number from C_ChallengeMode.GetActiveChallengeMapID
---@param keystoneLevel number from C_ChallengeMode.GetActiveKeystoneInfo
---@param encounterID number DungeonEncounterID from ENCOUNTER_END
---@return table|nil split Benchmark table, or nil if none is published
function API.GetSplit(mapChallengeModeID, keystoneLevel, encounterID)
	if type(encounterID) ~= "number" then
		return nil
	end

	local bosses = getLevel(mapChallengeModeID, keystoneLevel)
	if not bosses then
		return nil
	end

	local boss = bosses[encounterID]
	if type(boss) ~= "table" then
		return nil
	end

	return boss
end

---Returns every boss benchmark for one dungeon at one exact keystone level,
---keyed by DungeonEncounterID (see src\Data\Splits.lua).
---Useful for showing the whole route before the run starts. Each value has the
---same shape GetSplit returns, and `order` is where the game lists that boss in
---the dungeon - which is not always the order a group kills them in, so sort on
---it rather than assuming.
---Returns nil on any miss and never errors. The table is shared, not copied -
---treat it as read-only.
---@param mapChallengeModeID number from C_ChallengeMode.GetActiveChallengeMapID
---@param keystoneLevel number from C_ChallengeMode.GetActiveKeystoneInfo
---@return table|nil bosses Map of DungeonEncounterID to benchmark, or nil
function API.GetBosses(mapChallengeModeID, keystoneLevel)
	return getLevel(mapChallengeModeID, keystoneLevel)
end

---Returns the keystone levels this dungeon has a published pool for, ascending.
---
---This exists so a consumer can be useful about a level it has no data for.
---"No pace for +14 in Murder Row yet - the highest published is +12" is a true
---and helpful sentence; silently comparing that run against the +12 pool is
---neither, and is exactly what the exact-level rule exists to prevent. Say what
---is covered, do not reach into it.
---
---Returns nil for an unknown dungeon and never errors. A fresh table each call,
---so the caller may sort or keep it.
---@param mapChallengeModeID number from C_ChallengeMode.GetActiveChallengeMapID
---@return number[]|nil levels Ascending keystone levels, or nil if unknown
function API.GetLevels(mapChallengeModeID)
	local dungeon = getDungeon(mapChallengeModeID)
	if not dungeon or type(dungeon.levels) ~= "table" then
		return nil
	end

	local levels = {}
	for level in pairs(dungeon.levels) do
		levels[#levels + 1] = level
	end
	table.sort(levels)

	return levels
end

---Returns the dungeon's name as the journal spells it, in English.
---Deliberately not the client's localised name: the same id is the only stable
---handle, and the data is keyed on it. Consumers wanting the player's own
---language should resolve the id through C_ChallengeMode.GetMapUIInfo instead.
---@param mapChallengeModeID number from C_ChallengeMode.GetActiveChallengeMapID
---@return string|nil name Dungeon name, or nil if unknown
function API.GetDungeonName(mapChallengeModeID)
	local dungeon = getDungeon(mapChallengeModeID)
	if not dungeon or type(dungeon.name) ~= "string" then
		return nil
	end

	return dungeon.name
end

---Returns the game patch these pools were built on, as "major.minor" - "12.1".
---
---**Worth surfacing.** Every dungeon in this database was keyed on this patch
---and nothing here may be compared against a pool from another one, so if the
---game has moved on and the data has not been rebaked, this is the only thing
---that says so. A consumer showing a pace should be able to say which patch set
---it.
---@return string|nil partition Patch string, or nil if no data is published
function API.GetPartition()
	local data = addonTable.SplitsData
	if type(data) ~= "table" or type(data.partition) ~= "string" then
		return nil
	end

	return data.partition
end

---Returns the timestamp of the last generator run that produced this data.
---Format: "YYYY-MM-DD HH:MM:SS" (UTC). Intended for display only - it is a
---string, not a parsed time.
---@return string|nil updated Timestamp string, or nil if no data is published
function API.GetLastUpdate()
	local data = addonTable.SplitsData
	if type(data) ~= "table" or type(data.updated) ~= "string" then
		return nil
	end

	return data.updated
end
