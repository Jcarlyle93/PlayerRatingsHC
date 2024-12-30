local addonName, addon = ...
local frame = CreateFrame("Frame", "PlayerRaitingsWindow", UIParent, "BackDropTemplate")
local separator = frame:CreateTexture(nil, "OVERLAY")
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
local submitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
local dungeonInfoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local currentDungeonID = nil
local playerEntries = {}
local playerListContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")

playerListContainer:SetPoint("TOP", separator, "BOTTOM", 0, -10)
playerListContainer:SetSize(250, 200)

-- if user has been rated, then disable checkboxes.
local function UpdateRatingState(playerName)
  if addon.Core.HasRatedPlayerForDungeon and addon.Core.GetCurrentDungeonID then
    local dungeonID = addon.Core.GetCurrentDungeonID()
    if dungeonID then
      print("Checking rating state for:", playerName)
      print("Current dungeon ID:", dungeonID)
      
      local entry = playerEntries[playerName]
      if entry then
        local hasRated = addon.Core.HasRatedPlayerForDungeon(playerName, dungeonID)
        print("Has rated:", hasRated)
        
        entry.positiveCheck:SetEnabled(not hasRated)
        entry.negativeCheck:SetEnabled(not hasRated)
        
        if hasRated then
          entry.ratedText:SetText("Rated")
          entry.ratedText:Show()
        else
          entry.ratedText:Hide()
        end
      end
    end
  end
end

local function CreatePlayerEntry(playerName)
  local entry = CreateFrame("Frame", nil, playerListContainer)
  local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local positiveCheck = CreateFrame("CheckButton", nil, entry, "UICheckButtonTemplate")
  local negativeCheck = CreateFrame("CheckButton", nil, entry, "UICheckButtonTemplate")
  local ratedText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  if not playerListContainer.headersCreated then
    local plusHeader = playerListContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local minusHeader = playerListContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plusHeader:SetPoint("RIGHT", entry, "RIGHT", -25, 15) 
    minusHeader:SetPoint("RIGHT", plusHeader, "LEFT", -30, 0)
    plusHeader:SetText("+ 1")
    minusHeader:SetText("- 1")
    playerListContainer.headersCreated = true
  end

  entry:SetSize(250, 30)
  nameText:SetPoint("LEFT", entry, "LEFT", 10, -5)
  nameText:SetText(playerName)
  positiveCheck:SetPoint("RIGHT", entry, "RIGHT", -20, -5)
  negativeCheck:SetPoint("RIGHT", positiveCheck, "LEFT", -10, 0)
  ratedText:SetPoint("RIGHT", negativeCheck, "LEFT", -10, -5)
  ratedText:SetTextColor(0.5, 0.5, 0.5)
  ratedText:Hide()

  positiveCheck:SetScript("OnClick", function(self)
    if self:GetChecked() then
      negativeCheck:SetChecked(false)
    end
    print("Positive checked:", self:GetChecked())  -- Debug print
  end)
  
  negativeCheck:SetScript("OnClick", function(self)
    if self:GetChecked() then
      positiveCheck:SetChecked(false)
    end
    print("Negative checked:", self:GetChecked())  -- Debug print
  end)

  return {
    frame = entry,
    nameText = nameText,
    positiveCheck = positiveCheck,
    negativeCheck = negativeCheck,
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
  frame:SetHeight(math.max(200, totalHeight))
  print("Created", memberCount, "entries") -- Debug
end

-- Main UI Display
frame:SetSize(300, 200)
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
titleText:SetText("Player Ratings")

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

-- Submit Button
submitButton:SetSize(80, 25)
submitButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
submitButton:SetText("Submit")
submitButton:SetScript("OnClick", function()
  local anyRatingsGiven = false
  for playerName, entry in pairs(playerEntries) do
    if entry.positiveCheck:GetChecked() or entry.negativeCheck:GetChecked() then
        local isPositive = entry.positiveCheck:GetChecked()
        addon.Core.SendRating(playerName, isPositive)
        entry.positiveCheck:SetChecked(false)
        entry.negativeCheck:SetChecked(false)
        anyRatingsGiven = true
        UpdateRatingState(playerName)
    end
  end

  if not anyRatingsGiven then
      print("Please select at least one rating!")
  end
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
      self:AddLine(string.format("Player Rating: %+d", ratingData.rating), 
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