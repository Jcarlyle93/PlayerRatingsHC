local addonName, addon = ...

local ADDON_MSG_PREFIX = "PRHC"
local MSG_TYPE_RATING = "RATE"
local currentDungeonID = nil
local inDungeon = false
local partyMembers = {}
local inCombat = false
local SYNC_MSG_PREFIX = "PRHC_SYNC"
local lastUpdateRequest = 0
local UPDATE_THROTTLE = 300
local isSyncing = false

local SECURITY_KEYS = {
  "hK9$mP2#", "jL5*nQ7@", "rT3&vW4!", "xY8%zA6#" 
}

local TRANSFORM_KEYS = {
  PRIMARY = 0x5A791B24,
  SECONDARY = 0x3F8E2C9D,
  TERTIARY = 0x6B4D8E2A
}

PlayerRatingsHCDB = PlayerRatingsHCDB or {
  ratings = {},
  checksumData = {},
  validationLog = {},
  outgoingRatings = {},
  playerBewareList = {},
  dungeonCommends = {},
  version = 1
}

PlayerRatingsHCDB.ratings = PlayerRatingsHCDB.ratings or {}
PlayerRatingsHCDB.checksumData = PlayerRatingsHCDB.checksumData or {}
PlayerRatingsHCDB.validationLog = PlayerRatingsHCDB.validationLog or {}
PlayerRatingsHCDB.outgoingRatings = PlayerRatingsHCDB.outgoingRatings or {}
PlayerRatingsHCDB.playerBewareList = PlayerRatingsHCDB.playerBewareList or {}

addon.DB = PlayerRatingsHCDB

local function GetLongestOnlineGuildMember()
  if not IsInGuild() then return nil end
  
  local numMembers = GetNumGuildMembers()
  local longestOnlineMember = nil
  local longestOnlineTime = 0
  
  for i = 1, numMembers do
    local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
    if online and name ~= UnitName("player") then
      local lastOnline = select(12, GetGuildRosterInfo(i))
      if lastOnline and lastOnline > longestOnlineTime then
        longestOnlineMember = name
        longestOnlineTime = lastOnline
      end
    end
  end
  
  return longestOnlineMember
end

local function GetLatestListVersion()
  local latestVersion = 0
  for _, data in pairs(PlayerRatingsHCDB.playerBewareList) do
    if data.timestamp > latestVersion then
      latestVersion = data.timestamp
    end
  end
  return latestVersion
end

local function RequestListUpdate()
  if isSyncing then return end
  
  local now = time()
  if now - lastUpdateRequest < UPDATE_THROTTLE then return end
  
  local targetPlayer = GetLongestOnlineGuildMember()
  if targetPlayer then
    isSyncing = true
    C_ChatInfo.SendAddonMessage(SYNC_MSG_PREFIX, 
      "REQUEST_LIST:" .. GetLatestListVersion(), 
      "WHISPER", 
      targetPlayer)
    lastUpdateRequest = now
  end
end

local function HasRatedPlayerForDungeon(playerName, dungeonID)
  PlayerRatingsHCDB.outgoingRatings = PlayerRatingsHCDB.outgoingRatings or {}
  
  if not PlayerRatingsHCDB.outgoingRatings[dungeonID] then
    return false
  end

  return PlayerRatingsHCDB.outgoingRatings[dungeonID][playerName] == true
end

local function RecordOutgoingRating(playerName, dungeonID)
  PlayerRatingsHCDB.outgoingRatings[dungeonID] = PlayerRatingsHCDB.outgoingRatings[dungeonID] or {}
  PlayerRatingsHCDB.outgoingRatings[dungeonID][playerName] = true
end

local function TransformRating(rating, key)
  local transformed = rating
  transformed = bit.bxor(transformed * key, TRANSFORM_KEYS.PRIMARY)
  transformed = bit.rshift(transformed, 3) + bit.lshift(transformed, 29)
  transformed = bit.bxor(transformed, key * TRANSFORM_KEYS.SECONDARY)
  return transformed
end

local function GenerateComplexSignature(rating, timestamp, sender)
  local signatures = {}
  
  for _, key in ipairs(SECURITY_KEYS) do
    local str = rating .. timestamp .. sender .. key
    local hash = 0
    
    for i = 1, #str do
      local byte = string.byte(str, i)
      hash = bit.bxor(bit.lshift(hash, 5) + hash, byte)
      hash = hash + bit.band(hash, 0xFF)
    end
    
    hash = bit.bxor(hash, bit.rshift(hash, 16))
    hash = hash * 0x85ebca6b
    hash = bit.bxor(hash, bit.rshift(hash, 13))
    hash = hash * 0xc2b2ae35
    hash = bit.bxor(hash, bit.rshift(hash, 16))
    
    table.insert(signatures, hash)
  end
  
  local finalHash = 0
  for _, sig in ipairs(signatures) do
    finalHash = bit.bxor(finalHash, sig)
  end
  
  return finalHash
end

local function StoreRatingWithMultipleChecks(sender, rating, timestamp)

  PlayerRatingsHCDB.ratings[sender] = {
    rating = rating,
    timestamp = timestamp,
    signature = GenerateComplexSignature(rating, timestamp, sender),
  }
  
  PlayerRatingsHCDB.checksumData[sender] = {
    value = TransformRating(rating, TRANSFORM_KEYS.PRIMARY),
    timestamp = TransformRating(timestamp, TRANSFORM_KEYS.SECONDARY),
  }
  
  PlayerRatingsHCDB.validationLog[sender] = {
    checksum = TransformRating(rating, TRANSFORM_KEYS.TERTIARY),
    timekey = bit.bxor(timestamp, TRANSFORM_KEYS.PRIMARY)
  }
end

local function VerifyRatingIntegrity(sender)

  local mainData = PlayerRatingsHCDB.ratings[sender]
  if not mainData then 
    print("No main data found")  -- Debug
    return false 
  end
  
  local checksumData = PlayerRatingsHCDB.checksumData[sender]
  local validationData = PlayerRatingsHCDB.validationLog[sender]
  
  local expectedChecksum = TransformRating(mainData.rating, TRANSFORM_KEYS.PRIMARY)
  local expectedTimeTransform = TransformRating(mainData.timestamp, TRANSFORM_KEYS.SECONDARY)
  local expectedValidationChecksum = TransformRating(mainData.rating, TRANSFORM_KEYS.TERTIARY)
  local expectedTimeKey = bit.bxor(mainData.timestamp, TRANSFORM_KEYS.PRIMARY)
  local expectedChecksum = TransformRating(mainData.rating, TRANSFORM_KEYS.PRIMARY)
  local expectedTimeTransform = TransformRating(mainData.timestamp, TRANSFORM_KEYS.SECONDARY)
  local expectedValidationChecksum = TransformRating(mainData.rating, TRANSFORM_KEYS.TERTIARY)
  local expectedTimeKey = bit.bxor(mainData.timestamp, TRANSFORM_KEYS.PRIMARY)

  if checksumData.value ~= expectedChecksum or
     checksumData.timestamp ~= expectedTimeTransform or
     validationData.checksum ~= expectedValidationChecksum or
     validationData.timekey ~= expectedTimeKey then
    return false
  end

  -- Verify signature
  local expectedSignature = GenerateComplexSignature(mainData.rating, mainData.timestamp, sender)
  if mainData.signature ~= expectedSignature then
    return false
  end

  return true
end

local function HandleAddonMessage(message, sender)
  local msgType, target, rating = strsplit(":", message)
  
  if msgType == MSG_TYPE_RATING then
    if target == UnitName("player") then
      local currentRating = 0
      dungeonID = tonumber(dungeonID)
      
      if HasRatedPlayerForDungeon(sender, dungeonID) then
        print("You've already rated ")
        return
      end
      if PlayerRatingsHCDB.ratings[sender] and VerifyRatingIntegrity(sender) then
        currentRating = PlayerRatingsHCDB.ratings[sender].rating
      end

      StoreRatingWithMultipleChecks(
        sender, 
        currentRating + tonumber(rating),
        time()
      )

      print(string.format("Received and stored rating %s from %s", rating, sender))
    end
  end
end

local function UpdatePartyMembers()
  if not currentDungeonID then 
    print("not in dungeon")  -- Debug
    return 
  end

  if IsInGroup() then
    print("in group")  -- Debug
    for i = 1, GetNumGroupMembers() do
      local unit = "party" .. i
      local name = GetUnitName(unit, true)
      if name and name ~= UnitName("player") then
        if not string.find(name, "-") then
          local currentRealm = GetNormalizedRealmName()
          if currentRealm then
            name = name .. "-" .. currentRealm
            print("Added realm:", name)  -- Debug
          end
        end

        if not partyMembers[name] then
          partyMembers[name] = true
          print("Added party member", name) -- debug
        end
      end
    end
  end
end

local function CheckBewareList(playerName)
  return PlayerRatingsHCDB.playerBewareList[playerName] ~= nil
end

local function CheckPartyForBewareList()
  for i = 1, GetNumGroupMembers() do
    local name = GetRaidRosterInfo(i)
    if CheckBewareList(name) then
      RaidWarningFrame_OnEvent(RaidWarningFrame, "CHAT_MSG_RAID_WARNING", 
        format("WARNING: %s is on the player beware list!", name))
    end
  end
end

local function CheckTargetBewareStatus()
  local target = GetUnitName("target")
  if target and PlayerRatingsHCDB.playerBewareList[target] then
    RaidNotice_AddMessage(RaidWarningFrame, 
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t " .. 
    target .. 
    " in on the guild beware list!" ..
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    ChatTypeInfo["RAID_WARNING"])
    PlaySound(8959)
  end
end

local function CanManageBewareList()
  --local guildRank = select(1, GetGuildRankInfo(GetGuildRank()))
  return true
end

local function AddToBewareList(playerName, note)
  print("Adding to beware list:", playerName) -- Debug
  print("PlayerRatingsHCDB exists:", PlayerRatingsHCDB ~= nil) -- Debug
  print("playerBewareList exists:", PlayerRatingsHCDB.playerBewareList ~= nil) -- Debug

  if not playerName or playerName == "" then
    return false
  end

  playerName = playerName:gsub("^%a", string.upper)

  if not PlayerRatingsHCDB.playerBewareList then
    print("Creating new playerBewareList")  -- Debug
    PlayerRatingsHCDB.playerBewareList = {}
  end

  if PlayerRatingsHCDB.playerBewareList[playerName] then
    if note and note ~= "" then
      if not PlayerRatingsHCDB.playerBewareList[playerName] then
        PlayerRatingsHCDB.playerBewareList[playerName].note = {}
      end
      table.insert(PlayerRatingsHCDB.playerBewareList[playerName].notes, {
        addedBy = UnitName("player"),
        text = note,
        timestamp = time()
      })
    end
    return true
  end

  -- We might change this so only officers can manage, this is why for now this just returns true
  if not CanManageBewareList() then 
    return true 
  end
  
  PlayerRatingsHCDB.playerBewareList[playerName] = {
    addedBy = UnitName("player"),
    timestamp = time(),
    notes = note and note ~= "" and {
      {
        addedBy = UnitName("player"),
        text = note,
        timestamp = time()
      }
    } or {}
  }
  
  C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, "BEWARE_ADD:" .. playerName, "GUILD")
  return true
end

local function RemoveFromBewareList(playerName)
  if not CanManageBewareList() then return false end
  PlayerRatingsHCDB.playerBewareList[playerName] = nil
  return true
end

local function RemoveNote(playerName, noteToRemove)
  if PlayerRatingsHCDB.playerBewareList[playerName] and PlayerRatingsHCDB.playerBewareList[playerName].notes then
    local notes = PlayerRatingsHCDB.playerBewareList[playerName].notes
    for i, note in ipairs(notes) do
      if note.addedBy == noteToRemove.addedBy and note.text == noteToRemove.text then
        table.remove(notes, i)
        break
      end
    end
    if #notes == 0 then
      PlayerRatingsHCDB.playerBewareList[playerName].notes = {}
    end
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
eventFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" and ... == addonName then
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if prefix == ADDON_MSG_PREFIX then
      HandleAddonMessage(message, sender)
    end
  elseif event == "GROUP_ROSTER_UPDATE" or
         event == "PARTY_MEMBER_ENABLE" or
         event == "PARTY_MEMBER_DISABLE" then
    UpdatePartyMembers()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    local wasInDungeon = inDungeon
    UpdatePartyMembers()
    if instanceType == "party" then
      inDungeon = true
      if currentDungeonID ~= instanceID then
        currentDungeonID = instanceID
        currentDungeonName = name
        print("Entered Dungeon", name, "ID:", instanceID)  -- Debug
      end
    else
      inDungeon = false
      if wasInDungeon then
        print("Left Dungeon", currentDungeonName, currentDungeonID or "unknown") -- Debug
        lastDungeonID = currentDungeonID
        lastDungeonName = currentDungeonName
        addon.Core.UpdateDungeonInfo(lastDungeonName, lastDungeonID)
        addon.UI.mainFrame:Show()   
        currentDungeonID = nil
        currentDungeonName = nil    
      end
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    CheckTargetBewareStatus()
  elseif event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    if addon.bewareFrame and addon.bewareFrame:IsShown() then
      addon.bewareFrame:Hide()
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
  end
end)

addon.Core = {
  SendRating = function(targetPlayer, isPositive)
    local dungeonID = currentDungeonID or lastDungeonID
    if not dungeonID then
      print("Error: No dungeon ID available")  -- Debug
      return
    end
    if addon.DungeonTracker.HasGivenCommend(dungeonID) then
      print("You've already given a commendation for this dungeon run")
      return
    end
    if HasRatedPlayerForDungeon(targetPlayer, dungeonID) then
      print("You have already rated " .. targetPlayer .. " for this dungeon")  -- Debug
      return
    end
    local rating = isPositive and 1 or -1
    local message = string.format("%s:%s:%d", MSG_TYPE_RATING, targetPlayer, rating)
    C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, message, "WHISPER", targetPlayer)
    RecordOutgoingRating(targetPlayer, dungeonID)
  end,
  VerifyRatingIntegrity = VerifyRatingIntegrity,
  UpdateDungeonInfo = function(name, id)
    if addon.UI and addon.UI.SetDungeonInfo then
      addon.UI.SetDungeonInfo(string.format("Commend players for %s (ID: %s)", name, id))
    end
  end,
  HasRatedPlayerForDungeon = HasRatedPlayerForDungeon,
  SetCurrentDungeonID = function(id)
    currentDungeonID = id
    lastDungeonID = id
  end,
  GetCurrentDungeonID = function()
    return currentDungeonID or lastDungeonID 
  end,
  AddToBewareList = AddToBewareList,
  RemoveFromBewareList = RemoveFromBewareList,
  CanManageBewareList = CanManageBewareList,
  RemoveNote = RemoveNote
}