local addonName, addon = ...

PlayerRatingsHCDB.dungeonCommends = PlayerRatingsHCDB.dungeonCommends or {}

local DungeonTracker = {
  currentDungeonID = nil,
  currentDungeonName = nil,
  currentDungeonData = nil,
  bossKills = {},
  dungeonCompleted = false,
  commendGiven = PlayerRatingsHCDB.dungeonCommends
}


local function GetPlayerLevel()
  return UnitLevel("player")
end

local function UpdateCurrentDungeonData()
  DungeonTracker.currentDungeonData = DungeonTracker.currentDungeonName and 
      addon.DungeonData[DungeonTracker.currentDungeonName] or nil
  print(DungeonTracker.currentDungeonData) -- debug
end

local function IsDungeonLevelAppropriate()
  if not DungeonTracker.currentDungeonData then 
      print("No dungeon data found") -- Debug
      return false 
  end
  local playerLevel = UnitLevel("player")
  print("Player level:", playerLevel) -- Debug
  print("Dungeon cap:", DungeonTracker.currentDungeonData.level_cap) -- Debug
  return playerLevel <= DungeonTracker.currentDungeonData.level_cap
end

local function CheckBossKill(guid, name)
  if not DungeonTracker.currentDungeonName then
    return
  end

  local npcID = tonumber(string.match(guid, "Creature%-.-%-.-%-.-%-.-%-.-%-(.-)%"))
  if not npcID then
    return
  end

  if npcID == DungeonTracker.currentDungeonData.boss_id then
    DungeonTracker.bossKills[npcID] = true
    DungeonTracker.dungeonCompleted = true
    addon.UI.EnableCommdndations()
  end
end

local function ResetDungeonProgres()
  DungeonTracker.bossKills = {}
  DungeonTracker.dungeonCompleted = false
end

local function OnDungeonEnter()
  print("Checking level appropriateness") -- Debug
  if not IsDungeonLevelAppropriate() then
    RaidNotice_AddMessage(RaidWarningFrame, 
      "Your level exceeds the cap for commendations in this dungeon!", 
      ChatTypeInfo["RAID_WARNING"])
    PlaySound(5274)
  end
end

local function OnDungeonExit()
  if not IsDungeonLevelAppropriate() then
    addon.UI.UpdateCommendButtons(true)
  end
end

HasGivenCommend = function(dungeonID)
  return PlayerRatingsHCDB.dungeonCommends[dungeonID] or false
end

SetCommendGiven = function(dungeonID)
  PlayerRatingsHCDB.dungeonCommends[dungeonID] = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local _, eventType, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if eventType == "UNIT_DIED" then
      CheckBossKill(destGUID)
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "party" and instanceID ~= 409 and instanceID ~= 249 and instanceID ~= 309 and instanceID ~= 531 and instanceID ~= 509 then
      print("in instance") -- debug
      DungeonTracker.currentDungeonID = instanceID
      DungeonTracker.currentDungeonName = name
      UpdateCurrentDungeonData()
      ResetDungeonProgres()
      OnDungeonEnter()
    else
      OnDungeonExit()
      DungeonTracker.currentDungeonID = nil
      DungeonTracker.currentDungeonName = nil
      DungeonTracker.currentDungeonData = nil
      ResetDungeonProgres()
    end
  end
end)

addon.DungeonTracker = {
  IsDungeonCompleted = function() return DungeonTracker.dungeonCompleted end,
  IsLevelAppropiate = IsDungeonLevelAppropiate,
  GetCurrentDungeon = function() return DungeonTracker.currentDungeonName end,
  GetCurrentDungeonID = function() return DungeonTracker.currentDungeonID end,
  ResetProgress = ResetDungeonProgres,
  HasGivenCommend = function(dungeonID) return DungeonTracker.commendGiven[dungeonID] or false end,
  SetCommendGiven = function(dungeonID) DungeonTracker.commendGiven[dungeonID] = true end 
}