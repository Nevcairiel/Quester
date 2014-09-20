local Quester = LibStub("AceAddon-3.0"):NewAddon("Quester", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Quester")

local db
local defaults = {
	profile = {
		-- options
		removeComplete = true,
		highlightReward = true,

		-- sounds
		morework = true,
		jobsdone = true,

		-- sink
		sinkOptions = {
			sink20OutputSink = "UIErrorsFrame",
		},
	}
}

-- "Deformat" the pattern to find their argument order
local MatchObject, MatchMonster, MatchFaction, MatchErrObject, MatchErrFound, MatchErrKill, MatchErrCompleted
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
		local match_pattern = '^' .. pattern:gsub('%(','%%('):gsub('%)', '%%)'):gsub('(%%%d?$?[^()])', '(.-)') .. '$'
		return function(text) return permuteFn(text:match(match_pattern)) end
	end

	MatchObject = GetMatcher(QUEST_OBJECTS_FOUND)
	MatchMonster = GetMatcher(QUEST_MONSTERS_KILLED)
	MatchFaction = GetMatcher(QUEST_FACTION_NEEDED)

	MatchErrObject = GetMatcher(ERR_QUEST_ADD_ITEM_SII)
	MatchErrFound = GetMatcher(ERR_QUEST_ADD_FOUND_SII)
	MatchErrKill = GetMatcher(ERR_QUEST_ADD_KILL_SII)
	MatchErrCompleted = GetMatcher(ERR_QUEST_OBJECTIVE_COMPLETE_S)
end

-- utility functions
local function ColorGradient(perc, ...)
	if perc >= 1 then
		local r, g, b = select(select('#', ...) - 2, ...)
		return r, g, b
	elseif perc <= 0 then
		local r, g, b = ...
		return r, g, b
	end

	local num = select('#', ...) / 3

	local segment, relperc = math.modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

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
			title = format("|cff%s[%s] %s|r", rgb2hex(GetQuestDifficultyColor(level)), level, title)
		else
			title = format("[%s] %s", level, title)
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

local function getOptionsTable()
	local options = {
		type = "group",
		name = "Quester",
		get = function(k) return db[k.arg] end,
		set = function(k, v) db[k.arg] = v end,
		args = {
			behaviorheader = {
				type = "header",
				name = L["Behavior Configuration"],
				order = 1,
			},
			removeComplete = {
				name = L["Un-track complete quests"],
				desc = L["Toggle if completing a quest should automatically remove it from the tracker."],
				type = "toggle",
				arg = "removeComplete",
				order = 2,
			},
			highlightReward = {
				name = L["Highlight most valuable reward"],
				desc = L["Highlight the reward with the highest vendor value when completing a quest."],
				type = "toggle",
				arg = "highlightReward",
				order = 3,
			},
			soundheader = {
				type = "header",
				name = L["Sound Configuration"],
				order = 10,
			},
			sounddesc = {
				type = "description",
				name = L["Configure the sounds you want to hear with the toggles below."],
				order = 11,
			},
			morework = {
				name = L["More Work?!"],
				desc = L["Toggle playing the 'More Work?!' sound after completing an objective."],
				type = "toggle",
				arg = "morework",
				order = 12,
			},
			jobsdone = {
				name = L["Job's Done!"],
				desc = L["Toggle playing the 'Job's Done!' sound after completing a quest."],
				type = "toggle",
				arg = "jobsdone",
				order = 13,
			},
			header = {
				type = "header",
				name = L["Progress Output"],
				order = 20,
			},
			desc = {
				type = "description",
				name = L["You can select where you want progress messages displayed using the options below."],
				order = 21,
			},
			sink = Quester:GetSinkAce3OptionsDataTable(),
		}
	}

	-- hack sink options into submission
	options.args.sink.order = 22
	options.args.sink.inline = true
	options.args.sink.name = ""
	return options
end

local first = true
function Quester:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("QuesterDB", defaults, true)
	db = self.db.profile

	self:SetSinkStorage(self.db.profile.sinkOptions)

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Quester", getOptionsTable)
	local optFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Quester", "Quester")

	self:RegisterChatCommand("quester", function() InterfaceOptionsFrame_OpenToCategory(optFrame) end)
end

function Quester:OnEnable()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("GOSSIP_SHOW")
	self:RegisterEvent("QUEST_COMPLETE")

	--self:HookScript(GameTooltip, "OnTooltipSetItem")
	self:HookScript(GameTooltip, "OnTooltipSetUnit")
	self:SecureHook(QUEST_TRACKER_MODULE, "SetBlockHeader", "QuestTrackerSetHeader")
	self:SecureHook(QUEST_TRACKER_MODULE, "AddObjective", "ObjectiveTracker_AddObjective")
	self:SecureHook(BONUS_OBJECTIVE_TRACKER_MODULE, "AddObjective", "ObjectiveTracker_AddObjective")
	self:SecureHook("QuestLogQuests_Update")

	self:RawHookScript(UIErrorsFrame, "OnEvent", "UIErrorsFrame_OnEvent", true)

	self:EnvironmentProxy()
	self:QUEST_LOG_UPDATE()
	self:GOSSIP_SHOW()

	self:UpdateObjectiveTracker(QUEST_TRACKER_MODULE, true)
	self:UpdateObjectiveTracker(BONUS_OBJECTIVE_TRACKER_MODULE, false)

	if QuestFrameRewardPanel:IsVisible() then
		self:QUEST_COMPLETE()
	end
end

function Quester:UIErrorsFrame_OnEvent(frame, event, message)
	if event == "UI_INFO_MESSAGE" then
		local name, numItems, numNeeded = MatchErrObject(message)
		if not name then
			name, numItems, numNeeded = MatchErrKill(message)
		end
		if not name then
			name, numItems, numNeeded = MatchErrFound(message)
		end
		if not name then
			name = MatchErrCompleted(message)
			if name then
				numItems = 1
				numNeeded = 1
			end
		end
		if not name then
			if message == ERR_QUEST_UNKNOWN_COMPLETE then
				name = message
				numItems = 1
				numNeeded = 1
			end
		end
		if name then
			local perc = tonumber(numItems) / tonumber(numNeeded)
			self:Pour(message, ColorGradient(perc, 1,0,0, 1,1,0, 0,1,0))
			return
		end
	end
	return self.hooks[frame].OnEvent(frame, event, message)
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
					elseif objType == "event" or objType == "log" or objType == "spell" then
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

function ProcessGossip(index, skip, ...)
	local numQuests = select("#", ...)
	for i = 2, numQuests, skip do
		local button = _G["GossipTitleButton"..index]
		local text, col = button:GetText(), nil
		if text:match('^|c(.*)%[') then col, text = text:match("^|c(.*)%[[^%]]+%]%s?(.*)") end
		button:SetText(format('|cff%s[%d] %s|r', rgb2hex(GetQuestDifficultyColor(select(i, ...) or 0)), select(i,...) or 0, text))
		index = index + 1
	end
	return index + 1
end

function Quester:GOSSIP_SHOW()
	if not GossipFrame:IsVisible() then return end
	local buttonindex = 1
	if GetGossipAvailableQuests() then
		buttonindex = ProcessGossip(buttonindex, 6, GetGossipAvailableQuests())
	end
	if GetGossipActiveQuests() then
		buttonindex = ProcessGossip(buttonindex, 5, GetGossipActiveQuests())
	end
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
	local isSecure, addon = issecurevariable(block, "questLogIndex")
	if not isSecure then
		print("Quest Tracker tainted by " .. tostring(addon))
	end
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

function Quester:UpdateObjectiveTracker(tracker, hasHeader)
	for id, block in pairs(tracker.usedBlocks) do
		if block.used then
			if hasHeader then
				self:QuestTrackerSetHeader(tracker, block, block.HeaderText:GetText(), block.questLogIndex)
			end

			for key, line in pairs(block.lines) do
				self:ObjectiveTracker_AddObjective(tracker, block, key, line.Text:GetText(), line.type)
			end
		end
	end
end

function Quester:ObjectiveTracker_AddObjective(obj, block, objectiveKey, text, lineType, useFullHeight, hideDash, colorStyle)
	if progress[text] then
		local line = obj:GetLine(block, objectiveKey, lineType)
		line.Text:SetText(format("|cff%s%s|r", rgb2hex(ColorGradient(progress[text].perc, 1,0,0, 1,1,0, 0,1,0)), text))
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

function Quester:SetRewardHighlight(reward)
	if not self.rewardHighlightFrame then
		self.rewardHighlightFrame = CreateFrame("Frame", "QuesterRewardHighlight", QuestInfoRewardsFrame, "AutoCastShineTemplate")
		self.rewardHighlightFrame:SetScript("OnHide", function(self) AutoCastShine_AutoCastStop(self) end)
	end
	self.rewardHighlightFrame:ClearAllPoints()
	self.rewardHighlightFrame:SetAllPoints(reward)
	self.rewardHighlightFrame:Show()
	AutoCastShine_AutoCastStart(self.rewardHighlightFrame)
end

function Quester:QUEST_COMPLETE()
	if self.rewardHighlightFrame then
		self.rewardHighlightFrame:Hide()
	end

	if not db.highlightReward then return end

	local bestprice, bestitem = 0, 0
	for i = 1, GetNumQuestChoices() do
		local link, name, _, qty = GetQuestItemLink("choice", i), GetQuestItemInfo("choice", i)
		local price = link and select(11, GetItemInfo(link))
		if not price then return end
		price = price * (qty or 1)
		if price > bestprice then
			bestprice = price
			bestitem = i
		end
	end
	if bestitem > 0 then
		self:SetRewardHighlight(_G[("QuestInfoRewardsFrameQuestInfoItem%dIconTexture"):format(bestitem)])
	end
end
