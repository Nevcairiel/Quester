local Quester = LibStub("AceAddon-3.0"):NewAddon("Quester", "AceHook-3.0", "AceConsole-3.0", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Quester")

local db
local defaults = {
	profile = {
		-- options
		questLevels = false,
		removeComplete = true,
		highlightReward = true,
		trackerMovable = false,
		showObjectivePercentages = true,
		hide01 = true,
		shortenNumbers = false,
		showTagIcons = false,

		-- coloring
		gossipColor = true,
		questTrackerColor = true,
		tooltipColor = true,

		-- position
		pos = {
			x = nil,
			y = nil,
		},

		-- sounds
		soundSet = 1,
		morework = true,
		jobsdone = true,

		-- sink
		sinkOptions = {
			sink20OutputSink = "UIErrorsFrame",
		},
	}
}

-- "Deformat" the pattern to find their argument order
local MatchObject, MatchMonster, MatchPlayer, MatchFaction, MatchErrObject, MatchErrFound, MatchErrKill, MatchErrCompleted
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
		local pattern_opt = OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION:format(pattern)
		local match_pattern = "^" .. pattern:gsub("%(","%%("):gsub("%)", "%%)"):gsub("(%%%d?$?d)", "(.-)"):gsub("(%%%d?$?[^()])", "(.+)") .. "$"
		local match_pattern_opt = "^" .. pattern_opt:gsub("%(","%%("):gsub("%)", "%%)"):gsub("(%%%d?$?d)", "(.-)"):gsub("(%%%d?$?[^()])", "(.+)") .. "$"
		return function(text) local a,b,c = permuteFn(text:match(match_pattern_opt)) if not a then a,b,c = permuteFn(text:match(match_pattern)) end return a,b,c end
	end

	local function GetMatcherNonGreedy(pattern, greedyComponent)
		local permuteFn = loadstring(GetPermute3(pattern))()
		local pattern_opt = OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION:format(pattern)
		local match_pattern = "^" .. pattern:gsub("%(","%%("):gsub("%)", "%%)"):gsub("(%%%d?$?d)", "(.-)"):gsub(("(%%%%%d$[^()])"):format(greedyComponent), "(.+)"):gsub("(%%%d?$?[^()])", "(.-)") .. "$"
		local match_pattern_opt = "^" .. pattern_opt:gsub("%(","%%("):gsub("%)", "%%)"):gsub("(%%%d?$?d)", "(.-)"):gsub(("(%%%%%d$[^()])"):format(greedyComponent), "(.+)"):gsub("(%%%d?$?[^()])", "(.-)") .. "$"
		return function(text) local a,b,c = permuteFn(text:match(match_pattern_opt)) if not a then a,b,c = permuteFn(text:match(match_pattern)) end return a,b,c end
	end

	MatchObject = GetMatcher(QUEST_OBJECTS_FOUND)
	MatchMonster = GetMatcher(QUEST_MONSTERS_KILLED)
	MatchPlayer = GetMatcher(QUEST_PLAYERS_KILLED)
	MatchFaction = GetMatcherNonGreedy(QUEST_FACTION_NEEDED, 1)

	MatchErrObject = GetMatcher(ERR_QUEST_ADD_ITEM_SII)
	MatchErrFound = GetMatcher(ERR_QUEST_ADD_FOUND_SII)
	MatchErrKill = GetMatcher(ERR_QUEST_ADD_KILL_SII)
	MatchErrCompleted = GetMatcher(ERR_QUEST_OBJECTIVE_COMPLETE_S)
end

-- utility functions
local function ColorGradient(perc, ...)
	if perc >= 1 then
		local r, g, b = select(select("#", ...) - 2, ...)
		return r, g, b
	elseif perc <= 0 then
		local r, g, b = ...
		return r, g, b
	end

	local num = select("#", ...) / 3

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

local tags = {
	DAILY = "\226\128\162",
	GROUP = "+",
	SCENARIO = "s",
	DUNGEON = "d",
	HEROIC_DUNGEON = "d+",
	RAID = "r"
}

local function GetQuestTag(groupSize, frequency, tagId, tagName)
	local tag = ""
	if frequency == LE_QUEST_FREQUENCY_DAILY or frequency == LE_QUEST_FREQUENCY_WEEKLY then
		tag = tags.DAILY
	end
	if tagId == Enum.QuestTag.Group then
		tag = tag .. tags.GROUP
	elseif tagId == Enum.QuestTag.Scenario then
		tag = tag .. tags.SCENARIO
	elseif tagId == Enum.QuestTag.Dungeon then
		tag = tag .. tags.DUNGEON
	elseif tagId == Enum.QuestTag.Heroic then
		tag = tag .. tags.HEROIC_DUNGEON
	elseif QUEST_TAG_DUNGEON_TYPES[tagId] then
		tag = tag .. tags.RAID
	end
	return tag
end

local function GetTaggedTitle(i, color, tag)
	if not i or i == 0 then return nil end
	local title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(i)
	if not isHeader and title then
		local tagString = tag and GetQuestTag(groupSize, frequency, GetQuestTagInfo(questID)) or ""
		if color then
			if db.questLevels then
				title = format("|cff%s[%s%s] %s|r", rgb2hex(GetQuestDifficultyColor(level, isScaling)), level, tagString, title)
			else
				title = format("|cff%s%s|r", rgb2hex(GetQuestDifficultyColor(level, isScaling)), title)
			end
		elseif db.questLevels then
			title = format("[%s%s] %s", level, tagString, title)
		end
	end
	return title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling
end

local function GetChatTaggedTitle(i)
	if not i or i == 0 then return nil end
	local title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(i)
	if isHeader or not title then return end
	return format("(%s%s) %s", level, GetQuestTag(groupSize, frequency), title)
end

local function GetQuestTagTexCoords(i)
	if not i or i == 0 then return nil end
	local title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(i)

	local tagID
	local questTagID, tagName = GetQuestTagInfo(questID)
	if questTagID and questTagID == Enum.QuestTag.Account then
		local factionGroup = GetQuestFactionGroup(questID)
		if factionGroup then
			tagID = "ALLIANCE"
			if factionGroup == LE_QUEST_FACTION_HORDE then
				tagID = "HORDE"
			end
		else
			tagID = questTagID
		end
	elseif frequency == LE_QUEST_FREQUENCY_DAILY and (not isComplete or isComplete == 0) then
		tagID = "DAILY"
	elseif frequency == LE_QUEST_FREQUENCY_WEEKLY and (not isComplete or isComplete == 0)then
		tagID = "WEEKLY"
	elseif questTagID then
		tagID = questTagID
	elseif C_CampaignInfo.IsCampaignQuest(questID) then
		local faction = UnitFactionGroup("player")
		tagID = faction == "Horde" and "HORDE" or "ALLIANCE"
	end

	if tagID and QUEST_TAG_TCOORDS[tagID] then
		return QUEST_TAG_TCOORDS[tagID]
	end

	return nil
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
			trackerMovable = {
				name = L["Unlock Quest Tracker position"],
				desc = L["Unlock the position of the Objective Tracker, allowing it to be moved by clicking and dragging its header."],
				type = "toggle",
				order = 0,
				arg = "trackerMovable",
				width = "double",
				set = function(k, v) db.trackerMovable = v; Quester:ToggleTrackerMovable() end,
			},
			trackerReset = {
				name = L["Reset Position"],
				desc = L["Reset the position of the Objective Tracker to the default."],
				type = "execute",
				order = 0.5,
				func = function() db.pos.x = nil; db.pos.y = nil; UIParent_ManageFramePositions() end,
			},
			behaviorheader = {
				type = "header",
				name = L["Behavior Configuration"],
				order = 1,
			},
			questLevel = {
				name = L["Show Quest Level"],
				desc = L["Toggle if quest levels are shown in various parts of the UI."] .. "\n" .. L["Note: Changing this option may require your UI to be reloaded to take full effect."],
				type = "toggle",
				arg = "questLevels",
				order = 2,
				width = "full",
			},
			removeComplete = {
				name = L["Un-track complete quests"],
				desc = L["Toggle if completing a quest should automatically remove it from the tracker."],
				type = "toggle",
				arg = "removeComplete",
				order = 3,
				width = "full",
			},
			highlightReward = {
				name = L["Highlight most valuable reward"],
				desc = L["Highlight the reward with the highest vendor value when completing a quest."],
				type = "toggle",
				arg = "highlightReward",
				order = 4,
				width = "full",
			},
			showObjectivePercentages = {
				name = L["Always show objective percentage values on progress bars"],
				desc = L["Toggling this option may require a UI reload to fully take effect."],
				type = "toggle",
				arg = "showObjectivePercentages",
				order = 4.5,
				width = "full",
			},
			hide01 = {
				name = L["Remove numbers from single task objectives"],
				type = "toggle",
				arg = "hide01",
				order = 4.6,
				width = "full",
			},
			shortenNumbers = {
				name = L["Only show number of objective items remaining"],
				desc = L["Instead of 2/8, show 6"],
				type = "toggle",
				arg = "shortenNumbers",
				order = 4.6,
				width = "full",
			},
			showTagIcons = {
				name = L["Show Quest Tag Icons in the Objective Tracker"],
				desc = L["Allows easy identification of daily/weekly quests, as well as raid and dungeon quests."],
				type = "toggle",
				arg = "showTagIcons",
				order = 4.7,
				width = "full",
			},
			colorheader = {
				type = "header",
				name = L["Difficulty Coloring"],
				order = 5,
			},
			gossipColor = {
				name = L["Gossip frames"],
				desc = L["Enable the coloring of quests according to their difficulty on NPC Gossip frames."],
				type = "toggle",
				arg = "gossipColor",
				order = 6,
				width = "double",
			},
			questTrackerColor = {
				name = L["Quest Tracker"],
				desc = L["Enable the coloring of quests according to their difficulty in the quest tracker."],
				type = "toggle",
				arg = "questTrackerColor",
				order = 7,
				width = "double",
			},
			tooltipColor = {
				name = L["Tooltips"],
				desc = L["Enable the coloring of quests according to their difficulty in NPC and Item tooltips."],
				type = "toggle",
				arg = "tooltipColor",
				order = 8,
				width = "double",
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
			soundSet = {
				type = "select",
				name = L["Sound Set"],
				desc = L["Select the set of sounds to use."],
				arg = "soundSet",
				values = { L["Peasant"], L["Peon"] },
				order = 12,
			},
			sound_nl = {
				type = "description",
				name = "",
				order = 13,
			},
			morework = {
				name = L["More Work?!"],
				desc = L["Toggle playing the 'More Work?!' sound after completing an objective."],
				type = "toggle",
				arg = "morework",
				order = 15,
			},
			jobsdone = {
				name = L["Job's Done!"],
				desc = L["Toggle playing the 'Job's Done!' sound after completing a quest."],
				type = "toggle",
				arg = "jobsdone",
				order = 16,
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

local QUESTER_SOUND_MORE_WORK = 1
local QUESTER_SOUND_JOBS_DONE = 2

-- Sounds used. SoundKit IDs where available, file paths otherwise
local sounds = {
	[1] = {
		6288, -- "Sound\\Creature\\Peasant\\PeasantWhat3.ogg"
		"Interface\\AddOns\\Quester\\sounds\\jobsdone.ogg"
	},
	[2] = {
		6197, -- "Sound\\Creature\\Peon\\PeonYes3.ogg"
		6199, -- "Sound\\Creature\\Peon\\PeonBuildingComplete1.ogg"
	}
}
local function PlayQuestSound(index)
	local soundSet = db.soundSet
	if soundSet ~= 1 and soundSet ~= 2 then soundSet = 1 end
	local sound = sounds[soundSet][index]
	if type(sound) == "string" then
		PlaySoundFile(sound)
	elseif type(sound) == "number" then
		PlaySound(sound)
	end
end

local first, blockQuestUpdate = true, true
function Quester:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("QuesterDB", defaults, true)
	db = self.db.profile

	self:SetSinkStorage(self.db.profile.sinkOptions)

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Quester", getOptionsTable)
	local optFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Quester", "Quester")

	self:RegisterChatCommand("quester", function() InterfaceOptionsFrame_OpenToCategory(optFrame) end)

	self:RestoreTrackerPosition()
	hooksecurefunc("UpdateContainerFrameAnchors", function() Quester:RestoreTrackerPosition() end)

	self.eventFrame = CreateFrame("Frame", "QuesterEventFrame")
	self.eventFrame:SetScript("OnEvent", function(frame, event, ...) Quester:HandleEvent(event, ...) end)
end

function Quester:RestoreTrackerPosition()
	if db.pos.x and db.pos.y then
		ObjectiveTrackerFrame:ClearAllPoints()
		ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.pos.x, db.pos.y)
		ObjectiveTrackerFrame:SetPoint("BOTTOM", UIParent, "BOTTOM")
	end
end

function Quester:RegisterEvent(event)
	assert(self[event], "Event Handler missing for event " .. event)
	self.eventFrame:RegisterEvent(event)
end

function Quester:HandleEvent(event, ...)
	if event and self[event] then
		self[event](self, ...)
	end
end

function Quester:OnEnable()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("GOSSIP_SHOW")
	self:RegisterEvent("QUEST_GREETING")
	self:RegisterEvent("QUEST_COMPLETE")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")

	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	self:HookScript(GameTooltip, "OnTooltipSetItem")
	self:HookScript(GameTooltip, "OnTooltipSetUnit")
	self:SecureHook(QUEST_TRACKER_MODULE, "GetBlock", "QuestTrackerGetBlock")
	self:SecureHook(QUEST_TRACKER_MODULE, "OnFreeBlock", "QuestTrackerOnFreeBlock")
	self:SecureHook(QUEST_TRACKER_MODULE, "AddObjective", "ObjectiveTracker_AddObjective")
	self:SecureHook(BONUS_OBJECTIVE_TRACKER_MODULE, "AddObjective", "ObjectiveTracker_AddObjective")
	self:SecureHook(WORLD_QUEST_TRACKER_MODULE, "AddObjective", "ObjectiveTracker_AddObjective")
	self:SecureHook(QUEST_TRACKER_MODULE, "AddProgressBar", "ObjectiveTracker_AddProgressBar")
	self:SecureHook(BONUS_OBJECTIVE_TRACKER_MODULE, "AddProgressBar", "ObjectiveTracker_AddProgressBar")
	self:SecureHook(WORLD_QUEST_TRACKER_MODULE, "AddProgressBar", "ObjectiveTracker_AddProgressBar")
	self:SecureHook("QuestLogQuests_Update")

	self:RawHookScript(UIErrorsFrame, "OnEvent", "UIErrorsFrame_OnEvent", true)

	self:EnvironmentProxy()
	self:SetupChatFilter()

	if QuestFrameRewardPanel:IsVisible() then
		self:QUEST_COMPLETE()
	end

	if db.trackerMovable then
		self:ToggleTrackerMovable()
	end
end

function Quester:OnDisable()
	self.eventFrame:UnregisterAllEvents()
end

local function MakeBlockMovable(block, flag)
	block:EnableMouse(flag)

	if flag then
		if not block.QuesterMoveLock then
			block:SetScript("OnMouseDown", function() ObjectiveTrackerFrame:StartMoving() end)
			block:SetScript("OnMouseUp",
				function()
					ObjectiveTrackerFrame:StopMovingOrSizing()
					db.pos.x = ObjectiveTrackerFrame:GetLeft()
					db.pos.y = ObjectiveTrackerFrame:GetTop()
				end
			)
			local LockFrame = CreateFrame("Button", nil, block)
			LockFrame.lock = LockFrame:CreateTexture()
			LockFrame.lock:SetAllPoints(LockFrame)
			LockFrame.lock:SetTexture("Interface\\GuildFrame\\GuildFrame")
			LockFrame.lock:SetTexCoord(0.51660156, 0.53320313, 0.92578125, 0.96679688)
			LockFrame:SetSize(15, 18)
			LockFrame:SetPoint("TOPRIGHT", -16, -2)
			LockFrame:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT") GameTooltip:SetText(L["Lock the Objective Tracker in place"], 1, .82, 0, 1) GameTooltip:AddLine(L["You can unlock it again in the options"], 1, 1, 1, 1) GameTooltip:Show() end)
			LockFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
			LockFrame:SetScript("OnClick", function() db.trackerMovable = false; Quester:ToggleTrackerMovable() end)

			block.QuesterMoveLock = LockFrame
		end
		block.QuesterMoveLock:Show()
	else
		if block.QuesterMoveLock then
			block.QuesterMoveLock:Hide()
		end
	end
end

function Quester:ToggleTrackerMovable()
	if db.trackerMovable then
		ObjectiveTrackerFrame:SetMovable(true)
		ObjectiveTrackerFrame:SetClampedToScreen(true)
		ObjectiveTrackerFrame:SetClampRectInsets(-26, 0, 0, ObjectiveTrackerFrame:GetHeight() - 26)
		MakeBlockMovable(ObjectiveTrackerFrame.BlocksFrame.QuestHeader, true)
		MakeBlockMovable(ObjectiveTrackerFrame.BlocksFrame.AchievementHeader, true)
		MakeBlockMovable(ObjectiveTrackerFrame.BlocksFrame.ScenarioHeader, true)
	else
		ObjectiveTrackerFrame:SetMovable(false)
		MakeBlockMovable(ObjectiveTrackerFrame.BlocksFrame.QuestHeader, false)
		MakeBlockMovable(ObjectiveTrackerFrame.BlocksFrame.AchievementHeader, false)
		MakeBlockMovable(ObjectiveTrackerFrame.BlocksFrame.ScenarioHeader, false)
	end
end

function Quester:UIErrorsFrame_OnEvent(frame, event, ...)
	if event == "UI_INFO_MESSAGE" then
		local category, message = ...
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
			numItems, numNeeded = tonumber(numItems), tonumber(numNeeded)
			if numItems and numNeeded then
				local perc = numItems / numNeeded
				self:Pour(message, ColorGradient(perc, 1,0,0, 1,1,0, 0,1,0))
				return
			else
				--@debug@
				self:Print("Unable to parse objectives from message: " .. message)
				--@end-debug@
			end
		end
	end
	return self.hooks[frame].OnEvent(frame, event, ...)
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
	wipe(oldquests)
	complete, oldcomplete = oldcomplete, complete
	quests, oldquests = oldquests, quests

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

function Quester:UNIT_QUEST_LOG_CHANGED(unit, ...)
	if unit == "player" then
		self:QUEST_LOG_UPDATE()
	end
end

function Quester:QUEST_WATCH_LIST_CHANGED()
	self:QUEST_LOG_UPDATE()
end

function Quester:PLAYER_LEAVING_WORLD()
	blockQuestUpdate = true
end

function Quester:PLAYER_ENTERING_WORLD()
	blockQuestUpdate = nil
	self:QUEST_LOG_UPDATE()
end

local function processObjective(questID, questTitle, isTask, objIndex, objDesc, objType, objComplete)
	local itemDesc, numItems, numNeeded, objKey
	if objDesc then
		if objType == "item" or objType == "object" then
			itemDesc, numItems, numNeeded = MatchObject(objDesc)
			if itemDesc then
				if tonumber(numNeeded) and tonumber(numItems) and tonumber(numItems) > tonumber(numNeeded) then
					objKey = objDesc:gsub(numItems, numNeeded)
				end
				items[itemDesc] = objDesc -- used for tooltips
			else
				numItems, numNeeded = (objComplete and 1 or 0), 1
			end
		elseif objType == "monster" then
			itemDesc, numItems, numNeeded = MatchMonster(objDesc)
			if itemDesc == nil or numItems == nil or numNeeded == nil then
				--Sometimes we get objectives like "Find Mankrik's Wife: 0/1", which are listed as "monster".
				itemDesc, numItems, numNeeded = MatchObject(objDesc)
			end
			if itemDesc then
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
			end
		elseif objType == "player" then
			numItems, numNeeded, itemDesc = MatchPlayer(objDesc)

			-- it is unknown if some quests marked as "player" use the Monster syntax,
			-- but attempt to parse if it failed above
			if itemDesc == nil or numItems == nil or numNeeded == nil then
				itemDesc, numItems, numNeeded = MatchMonster(objDesc)
			end
		elseif objType == "reputation" then
			itemDesc, numItems, numNeeded = MatchFaction(objDesc)
			numItems, numNeeded = factionLabels[numItems], factionLabels[numNeeded]
		elseif objType == "event" or objType == "log" or objType == "spell" or objType == "progressbar" then
			itemDesc, numNeeded, numItems = objDesc, 1, (objComplete and 1 or 0)
		else
			--@debug@
			print("Unknown quest objective type: " .. objType .. ", on quest: " .. questTitle .. ", objective: " .. objDesc)
			--@end-debug@
		end
		numNeeded, numItems = tonumber(numNeeded), tonumber(numItems)
		if numNeeded and numNeeded > 0 and numItems then
			if not progress[objDesc] then
				progress[objDesc] = getTable()
			end
			progress[objDesc].q = questTitle
			progress[objDesc].qid = questID
			progress[objDesc].lid = objIndex
			progress[objDesc].i = numItems
			progress[objDesc].n = numNeeded
			progress[objDesc].perc = numItems / numNeeded
			progress[objDesc].done = objComplete
			local c = objKey or (questTitle .. objDesc)
			if objComplete then
				complete[c] = true
			end
			if not first and not complete[questTitle] and objComplete and not oldcomplete[c] and (not isTask or oldquests[questTitle]) then
				if db.morework then
					PlayQuestSound(QUESTER_SOUND_MORE_WORK)
				end
			end
		end
	end
end

function Quester:QUEST_LOG_UPDATE()
	-- check if updates are disabled (ie. during loading screens)
	if blockQuestUpdate then return end

	-- no re-entry
	blockQuestUpdate = true

	-- clear previous data cache
	emptyAll()

	-- store previous selection, so we can restore it
	local startingQuestLogSelection = GetQuestLogSelection()

	-- enumerate all quests
	local numEntries, numQuests = GetNumQuestLogEntries()
	for index = 1, numEntries do
		-- the quest log is stateful, and some functions require an active entry
		SelectQuestLogEntry(index)
		local title, level, groupSize, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory = GetQuestLogTitle(index)
		if not isHeader and not isBounty and questID and questID ~= 0 then
			-- Some other quest addons hook GetQuestLogTitle to add levels to the names.  This is annoying, so strip out the common format for it.
			if title:match("^%[") then title = title:match("^%[[^%]]+%]%s?(.*)") end

			-- store the quest in our lookup table
			quests[title] = questID

			-- process objectives
			local numObjectives = GetNumQuestLeaderBoards(index)
			if isComplete or numObjectives == 0 then
				if not first and not oldcomplete[title] and numObjectives > 0 then
					-- completed the quest
					if isComplete == -1 then
						self:Pour(ERR_QUEST_FAILED_S:format(title), 1, 0, 0)
					else
						self:Pour(ERR_QUEST_COMPLETE_S:format(title), 0, 1, 0)
						if db.jobsdone then
							PlayQuestSound(QUESTER_SOUND_JOBS_DONE)
						end
						if db.removeComplete and IsQuestWatched(index) then
							RemoveQuestWatch(index)
						end
					end
				end
				complete[title] = true
			end

			-- enumerate all objectives and store them
			for o = 1, numObjectives do
				processObjective(questID, title, isTask, o, GetQuestLogLeaderBoard(o, index))
			end
		end
	end
	if numEntries > 0 then first = nil end

	-- restore previous questlog selection
	SelectQuestLogEntry(startingQuestLogSelection)

	-- process watched world quests
	for i = 1, GetNumWorldQuestWatches() do
		local watchedWorldQuestID = GetWorldQuestWatchInfo(i)
		local isInArea, isOnMap, numObjectives, taskName, displayAsObjective = GetTaskInfo(watchedWorldQuestID)

		if taskName then
			quests[taskName] = watchedWorldQuestID
			for o = 1, numObjectives do
				processObjective(watchedWorldQuestID, taskName, true, o, GetQuestObjectiveInfo(watchedWorldQuestID, o, false))
			end
		end
	end

	-- update the objective tracker
	self:UpdateObjectiveTracker(QUEST_TRACKER_MODULE)
	self:UpdateObjectiveTracker(BONUS_OBJECTIVE_TRACKER_MODULE)
	self:UpdateObjectiveTracker(WORLD_QUEST_TRACKER_MODULE)

	-- update any open dialogs
	self:QUEST_GREETING()
	self:GOSSIP_SHOW()

	blockQuestUpdate = nil
end

local function ProcessGossip(index, skip, ...)
	local numQuests = select("#", ...)
	for i = 2, numQuests, skip do
		local button = _G["GossipTitleButton"..index]
		local text = button:GetText()
		if text:match("^|c(.*)%[") then
			local col, t = text:match("^|c(.*)%[[^%]]+%]|r%s?(.*)")
			if not t then
				col, t = text:match("^|c(.*)%[[^%]]+%]%s?(.*)")
			end
			if t then
				text = t
			end
		elseif text:match("^%[") then
			local t = text:match("^%[[^%]]+%]%s?(.*)")
			if t then
				text = t
			end
		end
		local level = select(i, ...) or 0
		if level == -1 then
			-- keep the text untouched
		elseif db.gossipColor then
			button:SetText(format("|cff%s[%d]|r %s", rgb2hex(GetQuestDifficultyColor(level)), level, text))
		else
			button:SetText(format("[%d] %s", level, text))
		end
		GossipResize(button)
		index = index + 1
	end
	return index + 1
end

function Quester:GOSSIP_SHOW()
	if not GossipFrame:IsVisible() or not db.questLevels then return end
	local buttonindex = 1
	if GetGossipAvailableQuests() then
		buttonindex = ProcessGossip(buttonindex, 7, GetGossipAvailableQuests())
	end
	if GetGossipActiveQuests() then
		buttonindex = ProcessGossip(buttonindex, 6, GetGossipActiveQuests())
	end
end

function Quester:QUEST_GREETING()
	if not QuestFrameGreetingPanel:IsVisible() or not db.questLevels then return end

	-- Enumerate over all available buttons, and modify them
	for button in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
		local title, level
		if button.isActive == 1 then
			title, level = GetActiveTitle(button:GetID()), GetActiveLevel(button:GetID())
		else
			title, level = GetAvailableTitle(button:GetID()), GetAvailableLevel(button:GetID())
		end
		if level == -1 then
			-- keep the text untouched
		elseif db.gossipColor then
			button:SetText(format("|cff%s[%d]|r %s", rgb2hex(GetQuestDifficultyColor(level)), level, title))
		else
			button:SetText(format("[%d] %s", level, title))
		end
		button:SetHeight(button:GetTextHeight() + 2)
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
				local index = GetQuestLogIndexByID(quests[text])
				if index and index > 0 then
					lines[i]:SetText(GetTaggedTitle(index, db.tooltipColor, true))
					tooltip:Show()
				end
			end
		end
	end
end

function Quester:OnTooltipSetItem(tooltip, ...)
	local name = tooltip:GetItem()
	if items[name] then
		local it = items[name]
		if progress[it] then
			local index = GetQuestLogIndexByID(progress[it].qid)
			if index and index > 0 then
				tooltip:AddLine(GetTaggedTitle(index, db.tooltipColor, true))
				local text = GetQuestLogLeaderBoard(progress[it].lid, index)
				if text then
					tooltip:AddLine(format(" - |cff%s%s|r", rgb2hex(ColorGradient(progress[it].perc, 1,0,0, 1,1,0, 0,1,0)), text))
				end
				tooltip:Show()
			end
		end
	end
end

function Quester:QuestLogQuests_Update()
	for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
		if button and button:IsShown() then
			local text = GetTaggedTitle(button.questLogIndex, false, false)

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
	QuestScrollFrame.Contents:Layout()
end

function Quester:UpdateObjectiveTracker(tracker)
	for _id, block in pairs(tracker.usedBlocks) do
		if block.used then
			for key, line in pairs(block.lines) do
				self:ObjectiveTracker_AddObjective(tracker, block, key, line.Text:GetText(), line.type)
			end
		end
	end
end

function Quester:QuestTrackerHeaderSetText(HeaderText, text)
	local block = HeaderText:GetParent()
	if HeaderText.__QuesterTagIcon then
		HeaderText.__QuesterTagIcon:Hide()
	end
	if block.__QuesterQuestTracker and block.id then
		local questLogIndex = GetQuestLogIndexByID(block.id)
		if questLogIndex then
			text = GetTaggedTitle(questLogIndex, db.questTrackerColor, true)
			HeaderText:__QuesterSetText(text)

			if db.showTagIcons then
				local tag = GetQuestTagTexCoords(questLogIndex)
				if tag then
					if not HeaderText.__QuesterTagIcon then
						HeaderText.__QuesterTagIcon = block:CreateTexture(nil, "ARTWORK")
						HeaderText.__QuesterTagIcon:SetSize(18, 18)
						HeaderText.__QuesterTagIcon:SetTexture("Interface\\QuestFrame\\QuestTypeIcons")
						HeaderText.__QuesterTagIcon:SetPoint("TOP", HeaderText, "TOP", 0, 3)
						HeaderText.__QuesterTagIcon:SetPoint("LEFT", HeaderText, "RIGHT", -2, 0)
					end
					HeaderText.__QuesterTagIcon:SetTexCoord(unpack(tag))
					HeaderText.__QuesterTagIcon:Show()
					HeaderText:SetWidth((block.lineWidth or OBJECTIVE_TRACKER_TEXT_WIDTH) - 6)
				end
			end
		end
	end
end

function Quester:QuestTrackerGetBlock(mod, questID)
	local block = mod.usedBlocks[questID]
	if block then
		if not block.__QuesterHooked then
			block.HeaderText.__QuesterSetText = block.HeaderText.SetText
			self:SecureHook(block.HeaderText, "SetText", "QuestTrackerHeaderSetText")
			block.__QuesterHooked = true
		end
		block.__QuesterQuestTracker = true
	end
end

function Quester:QuestTrackerOnFreeBlock(mod, block)
	block.__QuesterQuestTracker = nil
end

local function shorten_numbers(cur, total)
	if db.hide01 and total == "1" then
		return ""
	end
	if db.shortenNumbers then
		return tostring(total-cur).." "
	end
end

local function shorten_numbers_opt(opt, cur, total)
	local s = shorten_numbers(cur, total)
	if s then
		return ("%s %s"):format(opt, s)
	end
end

local objective_count = "^(%d+)/(%d+) "
local objective_count_opt = "^" .. OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION:format("QuesterPattern"):gsub("%(", "%(%%("):gsub("%)", "%%)%)"):gsub("QuesterPattern", "(%%d+)/(%%d+) ")

function Quester:ObjectiveTracker_AddObjective(obj, block, objectiveKey, text, lineType, useFullHeight, hideDash, colorStyle)
	if colorStyle == OBJECTIVE_TRACKER_COLOR["Header"] then
		if db.questTrackerColor then
			text = select(4, GetTaskInfo(block.id))
			if text then
				local line = obj:GetLine(block, objectiveKey, lineType)
				line.Text:SetText(format("|cff%s%s|r", rgb2hex(QuestDifficultyColors["difficult"]), text))
			end
		end
	else
		if progress[text] then
			local newText
			if db.shortenNumbers or db.hide01 then
				newText = text:gsub(objective_count, shorten_numbers):gsub(objective_count_opt, shorten_numbers_opt)
			end
			local line = obj:GetLine(block, objectiveKey, lineType)
			line.Text:SetText(format("|cff%s%s|r", rgb2hex(ColorGradient(progress[text].perc, 1,0,0, 1,1,0, 0,1,0)), newText or text))
		end
	end
end

function Quester:ObjectiveTracker_AddProgressBar(obj, block, line, questID)
	if db.showObjectivePercentages then
		line.ProgressBar.Bar:SetScript("OnEnter", nil)
		line.ProgressBar.Bar:SetScript("OnLeave", nil)
		line.ProgressBar.Bar.Label:Show()
	end
end

function Quester:EnvironmentProxy()
	local env = setmetatable({
		GetQuestLogTitle = function(index)
			return GetTaggedTitle(index, false, true)
		end,
	}, {__index = _G})

	-- quest log/map
	pcall(setfenv, WorldMapQuestPOI_SetTooltip, env)
	pcall(setfenv, WorldMapQuestPOI_AppendTooltip, env)
end

function Quester:SetupChatFilter()
	local function process(full, level, partial)
		return full:gsub(partial, quests[partial] and GetChatTaggedTitle(GetQuestLogIndexByID(quests[partial])) or "("..level..") "..partial)
	end
	local function filter(frame, event, msg, ...)
		if msg then
			if db.questLevels then
				msg = msg:gsub("(|c%x+|Hquest:%d+:(%d+)|h%[([^|]*)%]|h|r)", process)
			end
			return false, msg, ...
		end
	end
	for _,event in pairs{"SAY", "YELL", "GUILD", "GUILD_OFFICER", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "BATTLEGROUND", "BATTLEGROUND_LEADER", "CHANNEL"} do
		ChatFrame_AddMessageEventFilter("CHAT_MSG_"..event, filter)
	end
end

function Quester:SetRewardHighlight(reward)
	if not self.rewardHighlightFrame then
		self.rewardHighlightFrame = CreateFrame("Frame", "QuesterRewardHighlight", QuestInfoRewardsFrame, "AutoCastShineTemplate")
		self.rewardHighlightFrame:SetScript("OnHide", function(frame) AutoCastShine_AutoCastStop(frame) end)
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
