local Quester = LibStub("AceAddon-3.0"):NewAddon("Quester", "AceEvent-3.0", "AceHook-3.0", "LibSink-2.0")

local db
local defaults = {
	profile = {
		-- options
		removeComplete = true,

		-- sounds
		morework = true,
		jobsdone = true,

		-- sink
		sinkOptions = {},
	}
}

-- pattern used for objective parsing
local objects_pattern = '^' .. QUEST_OBJECTS_FOUND:gsub('(%%%d?$?.)', '(.-)') .. '$' --QUEST_OBJECTS_FOUND = "%s: %d/%d"
local monsters_pattern = '^' .. QUEST_MONSTERS_KILLED:gsub('(%%%d?$?.)', '(.-)') .. '$' --QUEST_MONSTERS_KILLED = "%s slain: %d/%d"
local faction_pattern = '^' .. QUEST_FACTION_NEEDED:gsub('(%%%d?$?.)', '(.-)') .. '$' --QUEST_FACTION_NEEDED = "%s: %s / %s"

-- match the object string
-- returns name, num, needed
local function MatchObject(description)
	local a, b, c = description:match(objects_pattern)

	-- %d/%d %s
	if GetLocale() == "enUS" or GetLocale() == "enGB" then
		return c, a, b
	end
	-- TODO: other locales
	return c, a, b
end

local function MatchMonster(description)
	local a, b, c = description:match(monsters_pattern)

	-- %s slain: %d/%d
	if GetLocale() == "enUS" or GetLocale() == "enGB" then
		return a, b, c
	end
	-- TODO: other locales
	return a, b, c
end

local function MatchFaction(description)
	local a, b, c = description:match(faction_pattern)

	-- %d/%d %s
	if GetLocale() == "enUS" or GetLocale() == "enGB" then
		return c, a, b
	end
	-- TODO: other locales
	return c, a, b
end

-- faction data for reputation quests
local factionLabels = {}
do
	local gender = UnitSex("player")
	for i=1, #FACTION_BAR_COLORS do
		local faction = GetText("FACTION_STANDING_LABEL"..i, gender)
		factionLabels[faction] = i
	end
end

-- data cache
local items, mobs, progress = {}, {}, {}
local table_cache = {}
local complete, oldcomplete = {}, {}
local quests = {}

local first = true
function Quester:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("Quester", defaults, true)
	db = self.db.profile

	self:SetSinkStorage(self.db.profile.sinkOptions)
end

function Quester:OnEnable()
	self:RegisterEvent("QUEST_LOG_UPDATE")

	self:QUEST_LOG_UPDATE()
end

local function getTable()
	local t = next(table_cache)
	if t then
		table_cache[t] = nil
	else t = {} end
	return t
end

local function emptyAll()
	wipe(items)
	wipe(oldcomplete)
	for k, v in pairs(complete) do
		oldcomplete[k] = v
		complete[k] = nil
	end
	for k, v in pairs(progress) do
		if type(v) == "table" then
			wipe(v)
			table_cache[v] = true
		end
		progress[k] = nil
	end
	for k, v in pairs(mobs) do
		if type(v) == "table" then
			wipe(v)
			table_cache[v] = true
		end
		mobs[k] = nil
	end
end

function Quester:QUEST_LOG_UPDATE()
	-- clear previous data cache
	emptyAll()
	wipe(quests)

	-- store previous selection, so we can restore it
	local startingQuestLogSelection = GetQuestLogSelection()

	-- enumerate all quests
	local numEntries, numQuests = GetNumQuestLogEntries()
	for index = 1, numEntries do
		-- the quest log is stateful, and some functions require an active entry
		SelectQuestLogEntry(index)
		local title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(index)
		if not isHeader then
			local questDescription, questObjectives = GetQuestLogQuestText(index)
			-- Some other quest addons hook GetQuestLogTitle to add levels to the names.  This is annoying, so strip out the common format for it.
			if title:match('^%[') then title = title:match("^%[[^%]]+%]%s?(.*)") end

			-- store the quest in our lookup table
			quests[title] = index

			-- process objectives
			local numObjectives = GetNumQuestLeaderBoards(index)
			if isComplete or numObjectives == 0 then
				if not first and not oldcomplete[title] and numObjectives > 0 then
					-- completed the quest
					self:Pour(ERR_QUEST_COMPLETE_S:format(title), 0, 1, 0)
					if db.jobsdone then
						PlaySoundFile("Interface\\AddOns\\Quester\\sounds\\jobsdone.mp3")
					end
					if db.removeComplete and IsQuestWatched(index) then
						RemoveQuestWatch(index)
					end
				end
				complete[title] = true
			end

			-- enumerate all objectives and store them
			for o = 1, numObjectives do
				local itemDesc, numItems, numNeeded
				local objDesc, objType, objComplete = GetQuestLogLeaderBoard(o, index)
				if objDesc then
					if objType == "item" or objType == "object" then
						itemDesc, numItems, numNeeded = MatchObject(objDesc)
						items[itemDesc] = objDesc -- used for tooltips
					elseif objType == "monster" then
						itemDesc, numItems, numNeeded = MatchMonster(objDesc)
						if itemDesc == nil or numItems == nil or numNeeded == nil then
							--Sometimes we get objectives like "Find Mankrik's Wife: 0/1", which are listed as "monster".
							itemDesc, numItems, numNeeded = MatchObject(objDesc)
						end
						if mobs[itemDesc] then
							if type(mobs[itemDesc]) == "string" then
								local s = mobs[itemDesc]
								mobs[itemDesc] = getTable()
								tinsert(mobs[itemDesc], s)
							end
							tinsert(mobs[itemDesc], objDesc)
						else
							mobs[itemDesc] = objDesc
						end
					elseif objType == "reputation" then
						itemDesc, numItems, numNeeded = MatchFaction(objDesc)
						numItems, numNeeded = factionLabels[numItems], factionLabels[numNeeded]
					elseif objType == "event" then
						itemDesc, numNeeded, numItems = objDesc, 1, (objComplete and 1 or 0)
					else
						print("Unknown quest objective type: " .. objType)
					end
					numNeeded, numItems = tonumber(numNeeded), tonumber(numItems)
					if numNeeded and numNeeded > 0 then
						if not progress[objDesc] then
							progress[objDesc] = getTable()
						end
						progress[objDesc].q = title
						progress[objDesc].qid = index
						progress[objDesc].lid = o
						progress[objDesc].i = numItems
						progress[objDesc].n = numNeeded
						progress[objDesc].perc = numItems / numNeeded
						progress[objDesc].done = objComplete
						local c = title .. objDesc
						if objComplete then
							complete[c] = true
						end
						if not first and not complete[title] and objComplete and not oldcomplete[c] then
							if db.morework then
								PlaySoundFile("Sound\\Creature\\Peasant\\PeasantWhat3.wav")
							end
						end
					end
				end
			end
		end
	end
	if numEntries > 0 then first = nil end

	-- restore previous questlog selection
	SelectQuestLogEntry(startingQuestLogSelection)
end
