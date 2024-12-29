local addonName, addon = ...

local ADDON_MSG_PREFIX = "PRHC"
local MSG_TYPE_RATING = "RATE"

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
  version = 1
}
addon.DB = PlayerRatingsHCDB

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
  -- Store in three different ways
  PlayerRatingsHCDB.ratings[sender] = {
    rating = rating,
    timestamp = timestamp,
    signature = GenerateComplexSignature(rating, timestamp, sender)
  }
  
  -- Store transformed version
  PlayerRatingsHCDB.checksumData[sender] = {
    value = TransformRating(rating, TRANSFORM_KEYS.PRIMARY),
    timestamp = TransformRating(timestamp, TRANSFORM_KEYS.SECONDARY)
  }
  
  -- Store another transformed version
  PlayerRatingsHCDB.validationLog[sender] = {
    checksum = TransformRating(rating, TRANSFORM_KEYS.TERTIARY),
    timekey = bit.bxor(timestamp, TRANSFORM_KEYS.PRIMARY)
  }
end

local function VerifyRatingIntegrity(sender)
  local mainData = PlayerRatingsHCDB.ratings[sender]
  local checksumData = PlayerRatingsHCDB.checksumData[sender]
  local validationData = PlayerRatingsHCDB.validationLog[sender]

  if not mainData or not checksumData or not validationData then
    return false
  end

  -- Verify transforms match
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
      -- Get current rating if it exists
      local currentRating = 0
      if PlayerRatingsHCDB.ratings[sender] and VerifyRatingIntegrity(sender) then
        currentRating = PlayerRatingsHCDB.ratings[sender].rating
      end

      -- Store new rating with all security measures
      StoreRatingWithMultipleChecks(
        sender, 
        currentRating + tonumber(rating),
        time()
      )

      print(string.format("Received and stored rating %s from %s", rating, sender))
    end
  end
end

-- Event Frame setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" and ... == addonName then
    -- DB is already initialized at file start
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if prefix == ADDON_MSG_PREFIX then
      HandleAddonMessage(message, sender)
    end
  end
end)

-- Expose necessary functions to addon namespace
addon.Core = {
  SendRating = function(targetPlayer, isPositive)
    local rating = isPositive and 1 or -1
    local message = string.format("%s:%s:%d", MSG_TYPE_RATING, targetPlayer, rating)
    C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, message, "WHISPER", targetPlayer)
  end,
  VerifyRatingIntegrity = VerifyRatingIntegrity
}