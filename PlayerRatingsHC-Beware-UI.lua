local addonName, addon = ...

local bewareUI = {
  listContentFrame = nil
}

local function UpdateBewareList()
  if not bewareUI.listContentFrame then
    return 
  end

  local children = {bewareUI.listContentFrame:GetChildren()}
  for _, child in pairs(children) do
    child:Hide()
  end

  local yOffset = -5
  for playerName, data in pairs(PlayerRatingsHCDB.playerBewareList) do
    local entry = CreateFrame("Frame", nil, bewareUI.listContentFrame, "BackdropTemplate")
    entry:SetSize(230, 25)
    entry:SetPoint("TOP", 0, yOffset)
    
    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 5, 0)
    nameText:SetText(playerName)
    
    local addedByText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addedByText:SetPoint("RIGHT", -25, 0)
    addedByText:SetText("Added by: " .. data.addedBy)
    
    local removeButton = CreateFrame("Button", nil, entry)
    removeButton:SetSize(16, 16)
    removeButton:SetPoint("RIGHT", -5, 0)
    removeButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    removeButton:SetScript("OnClick", function()
      if addon.Core.RemoveFromBewareList(playerName) then
        UpdateBewareList()
      end
    end)
    
    yOffset = yOffset - 30
  end
end

local function CreateBewareListUI()
  local frame = CreateFrame("Frame", "PlayerBewareWindow", UIParent, "BackdropTemplate")
  frame:SetSize(300, 400)
  frame:SetPoint("CENTER")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  
  frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  frame:SetBackdropColor(0, 0, 0, 0.8)

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

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Player Beware List")

  local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  editBox:SetSize(200, 20)
  editBox:SetPoint("TOP", title, "BOTTOM", 0, -20)
  editBox:SetAutoFocus(false)

  local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  addButton:SetSize(80, 25)
  addButton:SetPoint("TOP", editBox, "BOTTOM", 0, -5)
  addButton:SetText("Add")
  addButton:SetScript("OnClick", function()
    local name = editBox:GetText()
    if name and name ~= "" then
        if addon.Core.AddToBewareList(name) then
            editBox:SetText("")
            if bewareUI.listContentFrame then
              UpdateBewareList()
            else
            end
        end
    end
  end)

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetSize(230, 280)
  scrollFrame:SetPoint("TOP", addButton, "BOTTOM", 0, -10)

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -3, -3)
  closeButton:SetScript("OnClick", function() frame:Hide() end)

  bewareUI.listContentFrame = CreateFrame("Frame", nil, scrollFrame)
  bewareUI.listContentFrame:SetSize(230, 280)
  scrollFrame:SetScrollChild(bewareUI.listContentFrame)

  frame:SetScript("OnShow", function()
    UpdateBewareList()
  end)

  frame:Hide()
  return frame
end

addon.BewareUI = {
  CreateBewareListUI = CreateBewareListUI
}

SLASH_PLAYERBEWARE1 = "/beware"
SlashCmdList["PLAYERBEWARE"] = function(msg)
  if not addon.bewareFrame then
    addon.bewareFrame = CreateBewareListUI()
  end
  addon.bewareFrame:Show()
end