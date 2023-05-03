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

	-- API function groups
	"C_CampaignInfo",
	"C_GossipInfo",
	"C_QuestLog",
	"C_TaskQuest",

	-- API functions
	"CreateFrame",
	"GetActiveLevel",
	"GetActiveTitle",
	"GetAvailableLevel",
	"GetAvailableTitle",
	"GetItemInfo",
	"GetNumQuestChoices",
	"GetNumSubgroupMembers",
	"GetQuestFactionGroup",
	"GetQuestItemLink",
	"GetQuestItemInfo",
	"GetQuestLogLeaderBoard",
	"GetTaskInfo",
	"GetText",
	"PlaySound",
	"PlaySoundFile",
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
	"GetQuestDifficultyColor",
	"GossipFrame_GetTitleButton",
	"InterfaceOptionsFrame_OpenToCategory",
	"UIParent_ManageFramePositions",
	"TooltipDataProcessor",
	"TooltipUtil",

	-- FrameXML Misc
	"QuestDifficultyColors",
	"QUEST_TRACKER_MODULE",
	"CAMPAIGN_QUEST_TRACKER_MODULE",
	"BONUS_OBJECTIVE_TRACKER_MODULE",
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
	"GOSSIP_BUTTON_TYPE_ACTIVE_QUEST",
	"GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST",
	"LE_QUEST_FACTION_HORDE",
	"OBJECTIVE_TRACKER_COLOR",
	"OBJECTIVE_TRACKER_TEXT_WIDTH",
	"OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION",
	"QUEST_FACTION_NEEDED",
	"QUEST_MONSTERS_KILLED",
	"QUEST_OBJECTS_FOUND",
	"QUEST_PLAYERS_KILLED",
	"QUEST_TAG_DUNGEON_TYPES",
	"QUEST_TAG_ATLAS",
}
