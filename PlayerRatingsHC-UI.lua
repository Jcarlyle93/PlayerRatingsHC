local addonName, addon = ...
local frame = CreateFrame("Frame", "PlayerRaitingsWindow", UIParent, "BackDropTemplate")
local separator = frame:CreateTexture(nil, "OVERLAY")
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
local dungeonInfoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local currentDungeonID = nil
local playerEntries = {}
local playerListContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")

playerListContainer:SetPoint("TOP", separator, "BOTTOM", 0, -10)
playerListContainer:SetSize(250, 180)

-- if user has been rated, then disable checkboxes.
local function UpdateRatingState(playerName)
  if addon.Core.HasRatedPlayerForDungeon and addon.Core.GetCurrentDungeonID then
    local dungeonID = addon.Core.GetCurrentDungeonID()
    if dungeonID then
      print("Checking rating state for:", playerName) -- Debug
      print("Current dungeon ID:", dungeonID) -- Debug
      
      local entry = playerEntries[playerName]
      if entry then
        local hasRated = addon.Core.HasRatedPlayerForDungeon(playerName, dungeonID)
        print("Has rated:", hasRated) -- Debug
        
        entry.commendButton:SetEnabled(not hasRated)
        
        if hasRated then
          entry.commendButton:SetText("Submitted", 0, 1, 0)
        else
          return
        end
      end
    end
  end
end

local function CreatePlayerEntry(playerName)
  local entry = CreateFrame("Frame", nil, playerListContainer)
  local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local commendButton = CreateFrame("CheckButton", nil, entry, "UIPanelButtonTemplate")
  local ratedText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  entry:SetSize(250, 30)
  nameText:SetPoint("LEFT", entry, "LEFT", 10, -5)
  nameText:SetText(playerName)
  commendButton:SetSize(60, 20)
  commendButton:SetPoint("RIGHT", entry, "RIGHT", -20, -5)
  commendButton:SetText("Commend")
  ratedText:SetPoint("RIGHT", commendButton, "LEFT", -10, 0)
  ratedText:SetTextColor(0, 1, 0)
  ratedText:Hide()

  commendButton:SetScript("OnClick", function(self)
    addon.Core.SendRating(playerName, true)
    UpdateRatingState(playerName)
  end)

  return {
    frame = entry,
    nameText = nameText,
    commendButton = commendButton,
    ratedText = ratedText
  }
end

addon.UI = {}
addon.UI.mainFrame = frame
addon.UI.SetDungeonInfo = function(text)
  dungeonInfoText:SetText(text)
  currentDungeonID = dungeonID
end

addon.UI.UpdatePartyList = function(partyMembers)
  for _, entry in pairs(playerEntries) do
    entry.frame:Hide()
  end
  playerEntries = {}
  
  local yOffset = 0
  local memberCount = 0
  
  print("Creating entries for players:") -- Debug
  for playerName in pairs(partyMembers) do
    print("Creating for:", playerName) -- Debug
    local entry = CreatePlayerEntry(playerName)
    entry.frame:SetPoint("TOP", playerListContainer, "TOP", 0, yOffset)
    entry.frame:Show()
    playerEntries[playerName] = entry
    yOffset = yOffset - 35
    memberCount = memberCount + 1
  end
  
  local totalHeight = (memberCount * 35) + 100
  frame:SetHeight(math.max(180, totalHeight))
  print("Created", memberCount, "entries") -- Debug
end

-- Main UI Display
frame:SetSize(330, 180)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:Hide()

frame:SetBackdrop({
  bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.8)

titleText:SetPoint("TOP", frame, "TOP", 0, -10)
titleText:SetText("Commend Players")

dungeonInfoText:SetPoint("TOP", titleText, "BOTTOM", 0, -5)
dungeonInfoText:SetText("")

separator:SetHeight(1)
separator:SetWidth(frame:GetWidth() - 20)
separator:SetPoint("TOP", dungeonInfoText, "BOTTOM", 0, -10)
separator:SetColorTexture(0.6, 0.6, 0.6, 0.8)

frame:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
    self:StartMoving()
  end
end)

frame:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" then
    self:StopMovingOrSizing()
  end
end)

-- Exit Button
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -1)
closeButton:SetScript("OnClick", function()
  frame:Hide()
end)

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
  local name, unit = self:GetUnit()
  if not unit or not name then return end

  local fullName = name
  if unit then
    local currentRealm = GetNormalizedRealmName()
    if not string.find(name, "-") then  -- If name doesn't already include realm
      fullName = name .. "-" .. currentRealm
    end
  end

  print("Looking up rating for:", fullName)  -- Debug print
  
  if addon.DB and addon.DB.ratings then
    local ratingData = PlayerRatingsHCDB.ratings[fullName]
    if ratingData then
      local color = ratingData.rating > 0 and "00FF00" or "FF0000"
      self:AddLine(string.format("Commendations: %+d", ratingData.rating), 
        tonumber(string.sub(color, 1, 2), 16)/255,
        tonumber(string.sub(color, 3, 4), 16)/255,
        tonumber(string.sub(color, 5, 6), 16)/255)
    end
  end
end)

frame:SetScript("OnShow", function()
  local dungeonID = addon.Core.GetCurrentDungeonID()
  print("Current dungeon ID from Core:", dungeonID)
  UpdateRatingState(playerName)
end)

SLASH_PLAYERSRATINGSHC1 = "/prating"
SlashCmdList["PLAYERSRATINGSHC"] = function(msg)
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end