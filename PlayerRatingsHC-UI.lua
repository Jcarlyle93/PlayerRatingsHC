local addonName, addon = ...
local frame = CreateFrame("Frame", "PlayerRaitingsWindow", UIParent, "BackDropTemplate")
local separator = frame:CreateTexture(nil, "OVERLAY")
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
local playerContainer = CreateFrame("Frame", nil, frame)
local playerName = UnitName("player")
local nameText = playerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local positiveCheck = CreateFrame("CheckButton", nil, playerContainer, "UICheckButtonTemplate")
local negativeCheck = CreateFrame("CheckButton", nil, playerContainer, "UICheckButtonTemplate")
local submitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
local positiveText = playerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local negativeText = playerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local dungeonInfoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local ratedText = playerContainer:CreateFontString(nil,"OVERLAY", "GameFontNormal")
local currentDungeonID = nil

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

addon.UI = {}
addon.UI.mainFrame = frame
addon.UI.SetDungeonInfo = function(text)
  dungeonInfoText:SetText(text)
  currentDungeonID = dungeonID
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

positiveText:SetPoint("BOTTOM", positiveCheck, "TOP", 0, 2)
positiveText:SetText("+")

negativeText:SetPoint("BOTTOM", negativeCheck, "TOP", 0, 2)
negativeText:SetText("-")

-- Player List
playerContainer:SetSize(250, 30)
playerContainer:SetPoint("TOP", titleText, "BOTTOM", 0, -50)
nameText:SetPoint("LEFT", playerContainer, "LEFT", 10, 0)
nameText:SetText(playerName)
ratedText:SetPoint("RIGHT", negativeCheck, "LEFT", -10, 0)
ratedText:SetTextColor(0.5, 0.5, 0.5)
ratedText:Hide()

-- Exit Button
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -1)
closeButton:SetScript("OnClick", function()
  frame:Hide()
end)

-- Ratings Checkbox
positiveCheck:SetPoint("RIGHT", playerContainer, "RIGHT", -40, 0)
positiveCheck:SetScript("OnClick", function(self)
  if self:GetChecked() then
    negativeCheck:SetChecked(false)  -- Uncheck negative if positive is checked
  end
  print("Positive checked:", self:GetChecked())  -- Debug print
end)

negativeCheck:SetPoint("RIGHT", positiveCheck, "LEFT", -20, 0)
negativeCheck:SetScript("OnClick", function(self)
  if self:GetChecked() then
    positiveCheck:SetChecked(false)  -- Uncheck positive if negative is checked
  end
  print("Negative checked:", self:GetChecked())  -- Debug print
end)

-- Submit Button
submitButton:SetSize(80, 25)
submitButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
submitButton:SetText("Submit")
submitButton:SetScript("OnClick", function()
  -- Get the current rating selection
  if positiveCheck:GetChecked() or negativeCheck:GetChecked() then
    local isPositive = positiveCheck:GetChecked()
    addon.Core.SendRating(playerName, isPositive)
    positiveCheck:SetChecked(false)
    negativeCheck:SetChecked(false)
    
    UpdateRatingState(playerName)
    print("Rating sent for " .. playerName)
  else
    print("Please select a rating first!")
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