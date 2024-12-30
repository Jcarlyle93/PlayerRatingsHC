local addonName, addon = ...

local ADDON_MSG_PREFIX = "PRHC"
local MSG_TYPE_RATING = "RATE"
local currentDungeonID = nil
local inDungeon = false
local partyMembers = {}

local SECURITY_KEYS = {
  "hK9$mP2#", "jL5*nQ7@", "rT3&vW4!", "xY8%zA6#" 
}

local TRANSFORM_KEYS = {
  PRIMARY = 0x5A791B24,
  SECONDARY = 0x3F8E2C9D,
  TERTIARY = 0x6B4D8E2A
}

-- Initialize DB at the start
PlayerRatingsHCDB = PlayerRatingsHCDB or {
  ratings = {},
  checksumData = {},
  validationLog = {},
  outgoingRatings = {},
  version = 1
}

PlayerRatingsHCDB.ratings = PlayerRatingsHCDB.ratings or {}
PlayerRatingsHCDB.checksumData = PlayerRatingsHCDB.checksumData or {}
PlayerRatingsHCDB.validationLog = PlayerRatingsHCDB.validationLog or {}
PlayerRatingsHCDB.outgoingRatings = PlayerRatingsHCDB.outgoingRatings or {}

addon.DB = PlayerRatingsHCDB

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
    print("No main data found")
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
  if not currentDungeonID then return end

  if IsInGroup() then
    for i = 1, getNumGroupMembers() do
      local name = GetRaidRosterInfo(i)
      if name and name ~= UnitName("player") then
        if not string.find(name, "-") then
          name = name .. "-" .. GetNormalizedRealmName()
        end

        if not partyMembers[name] then
          partyMembers[name] = true
          print("Added party member", name) -- debug
        end
      end
    end
  end
end

-- Event Frame setups
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
eventFrame:RegisterEvent("PARTY_MEMBER_DISABLE")

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" and ... == addonName then
    -- DB is already initialized at file start
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

    if instanceType == "party" then
      inDungeon = true
      if currentDungeonID ~= instanceID then
        currentDungeonID = instanceID
        currentDungeonName = name
        print("Entered Dungeon", name, "ID:", instanceID)
      end
    else
      inDungeon = false
      if wasInDungeon then
        print("Left Dungeon", currentDungeonName, currentDungeonID or "unknown")
        lastDungeonID = currentDungeonID
        lastDungeonName = currentDungeonName
        addon.Core.UpdateDungeonInfo(lastDungeonName, lastDungeonID)
        addon.UI.mainFrame:Show()   
        currentDungeonID = nil
        currentDungeonName = nil    
      end
    end
  end
end)

-- Expose necessary functions to addon namespace
addon.Core = {
  SendRating = function(targetPlayer, isPositive)
    local dungeonID = currentDungeonID or lastDungeonID
    if not dungeonID then
      print("Error: No dungeon ID available")
      return
    end
    if HasRatedPlayerForDungeon(targetPlayer, dungeonID) then
      print("You have already rated " .. targetPlayer .. " for this dungeon")
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
      addon.UI.SetDungeonInfo(string.format("Rate players for %s (ID: %s)", name, id))
    end
  end,
  HasRatedPlayerForDungeon = HasRatedPlayerForDungeon,
  SetCurrentDungeonID = function(id)
    currentDungeonID = id
    lastDungeonID = id
  end,
  GetCurrentDungeonID = function()
    return currentDungeonID or lastDungeonID 
  end
}