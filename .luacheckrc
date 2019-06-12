std = "lua51"
max_line_length = false
exclude_files = {
	"libs/",
	".luacheckrc"
}

ignore = {
	"211/L", -- Unused local variable L
	"211", -- Unused local variable
	"212", -- Unused argument
	"213/_.*", -- Unused loop variable starting with _
	"231", -- Variable is never accessed
	"311", -- Value assigned to a local variable is unused
	"312", -- Value of argument is unused
	"542", -- empty if branch
}

globals = {

}

read_globals = {
	"format",
	"hooksecurefunc",
	"tinsert",
	"wipe",

	-- Third Party Addon/Libraries
	"LibStub",

	-- API functions
	"C_CampaignInfo",
	"CreateFrame",
	"GetActiveLevel",
	"GetActiveTitle",
	"GetAvailableLevel",
	"GetAvailableTitle",
	"GetGossipActiveQuests",
	"GetGossipAvailableQuests",
	"GetItemInfo",
	"GetNumActiveQuests",
	"GetNumAvailableQuests",
	"GetNumQuestChoices",
	"GetNumQuestLeaderBoards",
	"GetNumQuestLogEntries",
	"GetNumSubgroupMembers",
	"GetNumWorldQuestWatches",
	"GetQuestDifficultyColor",
	"GetQuestFactionGroup",
	"GetQuestItemInfo",
	"GetQuestItemLink",
	"GetQuestLogIndexByID",
	"GetQuestLogLeaderBoard",
	"GetQuestLogSelection",
	"GetQuestLogTitle",
	"GetQuestObjectiveInfo",
	"GetQuestTagInfo",
	"GetTaskInfo",
	"GetText",
	"GetWorldQuestWatchInfo",
	"IsQuestWatched",
	"IsUnitOnQuestByQuestID",
	"PlaySound",
	"PlaySoundFile",
	"RemoveQuestWatch",
	"SelectQuestLogEntry",
	"UnitFactionGroup",
	"UnitSex",

	-- FrameXML Frames
	"GameTooltip",
	"GossipFrame",
	"ObjectiveTrackerFrame",
	"QuestFrameGreetingPanel",
	"QuestFrameRewardPanel",
	"QuestInfoRewardsFrame",
	"QuestScrollFrame",
	"UIErrorsFrame",
	"UIParent",

	-- FrameXML Functions
	"AutoCastShine_AutoCastStart",
	"AutoCastShine_AutoCastStop",
	"ChatFrame_AddMessageEventFilter",
	"GossipResize",
	"InterfaceOptionsFrame_OpenToCategory",
	"UIParent_ManageFramePositions",
	"WorldMapQuestPOI_AppendTooltip",
	"WorldMapQuestPOI_SetTooltip",

	-- FrameXML Misc
	"BONUS_OBJECTIVE_TRACKER_MODULE",
	"QuestDifficultyColors",
	"QUEST_TRACKER_MODULE",
	"WORLD_QUEST_TRACKER_MODULE",

	-- FrameXML Constants
	"Enum",
	"ERR_QUEST_ADD_FOUND_SII",
	"ERR_QUEST_ADD_ITEM_SII",
	"ERR_QUEST_ADD_KILL_SII",
	"ERR_QUEST_COMPLETE_S",
	"ERR_QUEST_FAILED_S",
	"ERR_QUEST_OBJECTIVE_COMPLETE_S",
	"ERR_QUEST_UNKNOWN_COMPLETE",
	"FACTION_BAR_COLORS",
	"LE_QUEST_FACTION_HORDE",
	"LE_QUEST_FREQUENCY_DAILY",
	"LE_QUEST_FREQUENCY_WEEKLY",
	"OBJECTIVE_TRACKER_COLOR",
	"OBJECTIVE_TRACKER_TEXT_WIDTH",
	"OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION",
	"QUEST_FACTION_NEEDED",
	"QUEST_MONSTERS_KILLED",
	"QUEST_OBJECTS_FOUND",
	"QUEST_PLAYERS_KILLED",
	"QUEST_TAG_DUNGEON_TYPES",
	"QUEST_TAG_TCOORDS",
}
