-- Quester Locale
-- Please use the Localization App on WoWAce to Update this
-- http://www.wowace.com/projects/quester/localization/ ;¶

local debug = false
--@debug@
debug = true
--@end-debug@

local L = LibStub("AceLocale-3.0"):NewLocale("Quester", "enUS", true, debug)
--@localization(locale="enUS", format="lua_additive_table", same-key-is-true=true)@

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "deDE")
if L then
	--@localization(locale="deDE", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "esES")
if L then
	--@localization(locale="esES", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "esMX")
if L then
	--@localization(locale="esMX", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "frFR")
if L then
	--@localization(locale="frFR", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "itIT")
if L then
	--@localization(locale="itIT", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "koKR")
if L then
	--@localization(locale="koKR", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "ptBR")
if L then
	--@localization(locale="ptBR", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "ruRU")
if L then
	--@localization(locale="ruRU", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "zhCN")
if L then
	--@localization(locale="zhCN", format="lua_additive_table", handle-unlocalized="ignore")@
end

L = LibStub("AceLocale-3.0"):NewLocale("Mapster", "zhTW")
if L then
	--@localization(locale="zhTW", format="lua_additive_table", handle-unlocalized="ignore")@
end
