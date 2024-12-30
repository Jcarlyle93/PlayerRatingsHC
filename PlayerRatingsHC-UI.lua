local addonName, addon = ...
local frame = CreateFrame("Frame", "PlayerRaitingsWindow", UIParent, "BackDropTemplate")
local separator = frame:CreateTexture(nil, "OVERLAY")
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
local submitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
local dungeonInfoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local currentDungeonID = nil
local playerEntries = {}
local playerListContainer = CreateFrame("frame", nil, frame)

-- if user has been rated, then disable checkboxes.
local function UpdateRatingState(playerName)
  if addon.Core.HasRatedPlayerForDungeon and addon.Core.GetCurrentDungeonID  then
    local dungeonID = addon.Core.GetCurrentDungeonID()
    if dungeonID then
      print("Checking rating state for:", playerName)
      print("Current dungeon ID:", dungeonID)
      local hasRated = addon.Core.HasRatedPlayerForDungeon(playerName, dungeonID)
      print("Has rated:", hasRated)
    
      positiveCheck:SetEnabled(not hasRated)
      negativeCheck:SetEnabled(not hasRated)
    
      if hasRated then
        ratedText:SetText("Rated")
        ratedText:Show()
      else
        ratedText:Hide()
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

  entry:SetSize(250, 30)
  nameText:SetPoint("LEFT", entry, "LEFT", 10, 0)
  nametext:SetText(playerName)
  positiveCheck:SetPoint("RIGHT", entry, "RIGHT", -40, 0)
  negativeCheck:SetPoint("RIGHT", positiveCheck, "LEFT", -20, 0)
  ratedText:SetPoint("RIGHT", negativeCheck, "LEFT", -10, 0)
  ratedText:SetTextColor(0.5, 0.5, 0.5)
  ratedText:Hide()

  positiveCheck:SetScript("OnClick", function(self)
    if self:GetChecked() then
      negativeCheck:SetChecked(false)  -- Uncheck negative if positive is checked
    end
    print("Positive checked:", self:GetChecked())  -- Debug print
  end)
  
  negativeCheck:SetScript("OnClick", function(self)
    if self:GetChecked() then
      positiveCheck:SetChecked(false)  -- Uncheck positive if negative is checked
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
  for playerName in pairs(partyMembers) do
      local entry = CreatePlayerEntry(playerName)
      entry.frame:SetPoint("TOP", playerListContainer, "TOP", 0, yOffset)
      entry.frame:Show()
      playerEntries[playerName] = entry
      yOffset = yOffset - 35 
  end
  
  local totalHeight = math.abs(yOffset) + 100
  frame:SetHeight(math.max(200, totalHeight))
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

-- Unit Tooltip Score Display
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
  local name, unit = self:GetUnit()
  if not unit or not name then return end

  -- Get full name with realm
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