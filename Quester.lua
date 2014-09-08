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

-- "Deformat" the pattern to find their argument order
local MatchObject, MatchMonster, MatchFaction
do
	local function GetPermute3(pattern)
		local one, two, three = pattern:match("%%(%d)%$.+%%(%d)%$.+%%(%d)%$")
		if one and two and three then
			return ("return function(r%d, r%d, r%d) return r1, r2, r3 end"):format(one, two, three)
		end
		return "return function(...) return ... end"
	end

	local function GetMatcher(pattern)
		local permuteFn = loadstring(GetPermute3(pattern))()
		local match_pattern = '^' .. pattern:gsub('(%%%d?$?.)', '(.-)') .. '$'
		return function(text) return permuteFn(text:match(match_pattern)) end
	end

	MatchObject = GetMatcher(QUEST_OBJECTS_FOUND)
	MatchMonster = GetMatcher(QUEST_MONSTERS_KILLED)
	MatchFaction = GetMatcher(QUEST_FACTION_NEEDED)
end

-- utility functions
local function rgb2hex(r, g, b)
	if type(r) == "table" then
		g = r.g
		b = r.b
		r = r.r
	end
	return format("%02x%02x%02x", r*255, g*255, b*255)
end

local function GetTaggedTitle(i, color)
	local title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(i)
	if not isHeader and title then
		if color then
			title = string.format("|cff%s[%s] %s|r", rgb2hex(GetQuestDifficultyColor(level)), level, title)
		else
			title = string.format("[%s] %s", level, title)
		end
	end
	return title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory
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
local quests, oldquests = {}, {}

local first = true
function Quester:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("Quester", defaults, true)
	db = self.db.profile

	self:SetSinkStorage(self.db.profile.sinkOptions)
end

function Quester:OnEnable()
	self:RegisterEvent("QUEST_LOG_UPDATE")

	--self:HookScript(GameTooltip, "OnTooltipSetItem")
	self:HookScript(GameTooltip, "OnTooltipSetUnit")
	self:SecureHook(QUEST_TRACKER_MODULE, "SetBlockHeader", "QuestTrackerSetHeader")
	self:SecureHook("QuestLogQuests_Update")

	self:EnvironmentProxy()
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
	wipe(oldquests)
	for k, v in pairs(quests) do
		oldquests[k] = v
		quests[k] = nil
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
					elseif objType == "event" or objType == "log" then
						itemDesc, numNeeded, numItems = objDesc, 1, (objComplete and 1 or 0)
					else
						print("Unknown quest objective type: " .. objType .. ", on quest: " .. title .. ", objective: " .. objDesc)
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
						if not first and not complete[title] and objComplete and not oldcomplete[c] and (not isTask or oldquests[title]) then
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

local lines = {}
do
	local i = 1
	repeat
		lines[i] = _G["GameTooltipTextLeft"..i]
		i = i + 1
	until not _G["GameTooltipTextLeft"..i]
end

function Quester:OnTooltipSetUnit(tooltip, ...)
	local numLines = tooltip:NumLines()
	for i = 1, numLines do
		if lines[i] then
			local text = lines[i]:GetText()
			if quests[text] then
				lines[i]:SetText(GetTaggedTitle(quests[text], true))
				tooltip:Show()
			end
		end
	end
end

function Quester:QuestTrackerSetHeader(_, block, text, questLogIndex)
	text = GetTaggedTitle(questLogIndex, true)
	local height = QUEST_TRACKER_MODULE:SetStringText(block.HeaderText, text, nil, OBJECTIVE_TRACKER_COLOR["Header"]);
	-- taint check
	--print(issecurevariable(block, "questLogIndex"))
end

function Quester:QuestLogQuests_Update()
	for i = 1, #QuestMapFrame.QuestsFrame.Contents.Titles do
		local button = QuestMapFrame.QuestsFrame.Contents.Titles[i]
		if button and button:IsShown() then
			local text = GetTaggedTitle(button.questLogIndex, false)

			local partyMembersOnQuest = 0
			for j=1, GetNumSubgroupMembers() do
				if IsUnitOnQuestByQuestID(button.questID, "party"..j) then
					partyMembersOnQuest = partyMembersOnQuest + 1
				end
			end

			if partyMembersOnQuest > 0 then
				text = "["..partyMembersOnQuest.."] "..text
			end

			-- store previous text height, so we can compute the new total height
			local prevTextHeight = button.Text:GetHeight()

			-- update text
			button.Text:SetText(text)

			-- re-anchor check mark
			if button.Check:IsShown() then
				button.Check:SetPoint("LEFT", button.Text, button.Text:GetWrappedWidth() + 2, 0)
			end

			-- compute new button height, in case text wrapping changed
			local totalHeight = button:GetHeight()
			totalHeight = totalHeight - prevTextHeight + button.Text:GetHeight()
			button:SetHeight(totalHeight)
		end
	end
end

function Quester:EnvironmentProxy()
	local env = setmetatable({
		GetQuestLogTitle = function(index)
			return GetTaggedTitle(index, false)
		end,
	}, {__index = _G})

	-- quest log/map
	setfenv(WorldMapQuestPOI_SetTooltip, env)
	setfenv(WorldMapQuestPOI_AppendTooltip, env)
end
